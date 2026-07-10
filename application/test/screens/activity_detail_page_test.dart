import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/activity_note.dart';
import 'package:application/core/models/planned_trail.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:application/screens/activity_detail_page.dart';
import 'package:application/screens/navigator.dart';
import 'package:application/services/phone_wear_sync.dart';
import 'package:application/services/service_locator.dart';
import 'package:application/services/trail_geometry_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../mocks/mocks_manual.dart';
import '../utils/pump_app.dart';
import '../utils/test_config.dart';

typedef OnActivitySavedCallback =
    Future<void> Function({
      required double distance,
      required Duration elapsed,
      required double elevationGap,
    });

typedef OnNavigateAfterStop = void Function();

Future<void> dummyOnActivitySavedCallback({
  required double distance,
  required Duration elapsed,
  required double elevationGap,
}) async {}

void dummyNavigateAfterStop() {}

class MockTrailGeometryDataSource extends Mock
    implements TrailGeometryDataSource {}

class MockGeolocatorPlatform extends Mock
  with MockPlatformInterfaceMixin
  implements GeolocatorPlatform {}

class FakeWeatherHttpOverrides extends HttpOverrides {
  final bool shouldFail;
  FakeWeatherHttpOverrides({this.shouldFail = false});

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeWeatherHttpClient(shouldFail);
}

class _FakeWeatherHttpClient extends Fake implements HttpClient {
  final bool shouldFail;
  _FakeWeatherHttpClient(this.shouldFail);

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeWeatherHttpRequest(shouldFail);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeWeatherHttpRequest(shouldFail);
  }
}

class _FakeWeatherHttpRequest extends Fake implements HttpClientRequest {
  final bool shouldFail;
  _FakeWeatherHttpRequest(this.shouldFail);

  @override
  bool followRedirects = false;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = true;

  @override
  HttpHeaders get headers => _FakeHeaders();

  @override
  Future<HttpClientResponse> close() async =>
      _FakeWeatherHttpResponse(shouldFail);

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain();
  }
}

class _FakeHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) action) {}
}

class _FakeWeatherHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final bool shouldFail;
  _FakeWeatherHttpResponse(this.shouldFail);

  @override
  int get statusCode => shouldFail ? 500 : 200;

  @override
  int get contentLength => _getBody().length;

  @override
  String get reasonPhrase => shouldFail ? 'Server Error' : 'OK';

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _FakeHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  bool get persistentConnection => true;

  List<int> _getBody() {
    if (shouldFail) return utf8.encode('Internal Server Error');
    final targetDate = DateTime.now().add(const Duration(days: 5));
    final dateStr = targetDate.toIso8601String().split('T')[0];
    final jsonStr = jsonEncode({
      "daily": {
        "time": [dateStr],
        "weather_code": [800],
        "temperature_2m_max": [25.0],
        "temperature_2m_min": [15.0],
        "precipitation_probability_max": [10],
        "wind_speed_10m_max": [15.0],
      },
      "hourly": {
        "time": [
          "${dateStr}T10:00",
          "${dateStr}T11:00",
          "${dateStr}T12:00",
          "${dateStr}T13:00",
          "${dateStr}T14:00",
          "${dateStr}T15:00",
          "${dateStr}T16:00",
          "${dateStr}T17:00",
        ],
        "weather_code": [800, 801, 802, 700, 600, 500, 300, 200],
        "temperature_2m": [20.0, 21.0, 22.0, 20.0, 18.0, 19.0, 15.0, 14.0],
        "precipitation_probability": [0, 0, 10, 20, 80, 90, 100, 100],
      },
    });
    return utf8.encode(jsonStr);
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_getBody()).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockActivityCubit mockActivityCubit;
  late MockProfileCubit mockProfileCubit;
  late MockGeolocatorPlatform mockGeolocator;

  setUpAll(() {
    dotenv.loadFromString(envString: 'MAPBOX_ACCESS_TOKEN=test_token_123');
    HttpOverrides.global = FakeWeatherHttpOverrides();
    setupTest();
  });

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;

    when(() => mockGeolocator.isLocationServiceEnabled())
        .thenAnswer((_) async => true);
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) async => LocationPermission.always);
    when(() => mockGeolocator.getServiceStatusStream())
        .thenAnswer((_) => const Stream.empty());
    when(() => mockGeolocator.getLastKnownPosition())
        .thenAnswer((_) async => null);
    when(
      () => mockGeolocator.getCurrentPosition(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenAnswer(
      (_) async => Position(
        longitude: 12.4900,
        latitude: 41.8900,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ),
    );
    when(
      () => mockGeolocator.getPositionStream(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenAnswer((_) => const Stream.empty());

    mockActivityCubit = MockActivityCubit();
    mockProfileCubit = MockProfileCubit();

    when(() => mockActivityCubit.state).thenReturn([]);
    when(() => mockActivityCubit.stream).thenAnswer((_) => Stream.empty());
    when(
      () => mockActivityCubit.deleteActivity(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockActivityCubit.loadActivityDetails(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockActivityCubit.getPlannedTrail(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockActivityCubit.deleteNote(any(), any()),
    ).thenAnswer((_) async {});

    when(() => mockProfileCubit.stream).thenAnswer((_) => Stream.empty());
  });

  Activity createDummyActivity({
    ActivityStatus status = ActivityStatus.planned,
    List<ActivityNote>? notes,
    ActivityDifficulty difficulty = ActivityDifficulty.moderate,
    int daysFromNow = 5,
    String trailName = 'Sentiero 65',
    String trailId = '12345',
  }) {
    return Activity(
      id: 'act_123',
      name: 'Escursione al Monte Baldo',
      trailName: trailName,
      trailId: trailId,
      difficulty: difficulty,
      date: DateTime.now().add(Duration(days: daysFromNow)),
      durationMinutes: 120,
      distanceKm: 5.5,
      xpEarned: 150,
      trackedElevationGap: 400,
      trackedDistance: 5.2,
      trackedTime: const Duration(minutes: 125),
      status: status,
      notes:
          notes ??
          [
            ActivityNote(
              id: 'note_test',
              text: 'Test notes',
              imageUrls: const [],
              createdAt: DateTime.now(),
            ),
          ],
    );
  }

  Widget createWidgetUnderTest(
    Activity activity, {
    TrailGeometryDataSource? trailGeometrySource,
  }) {
    return MaterialApp(
      home: BlocProvider<ActivityCubit>.value(
        value: mockActivityCubit,
        child: ActivityDetailPage(
          activity: activity,
          trailGeometrySource: trailGeometrySource,
        ),
      ),
    );
  }

  group('ActivityDetailPage Widget Tests', () {
    testWidgets('downloads geometry online when Start is pressed', (
      tester,
    ) async {
      final geometrySource = MockTrailGeometryDataSource();
      final completer = Completer<List<List<LatLng>>>();
      when(
        () => geometrySource.fetchTrailPath('12345'),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        createWidgetUnderTest(
          createDummyActivity(daysFromNow: 20),
          trailGeometrySource: geometrySource,
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('Downloading...'), findsOneWidget);

      completer.complete(const []);
      await tester.pumpAndSettle();

      expect(find.text('Trail geometry is not available.'), findsOneWidget);
      verify(() => geometrySource.fetchTrailPath('12345')).called(1);
    });

    testWidgets('uses cached trail geometry when Start is pressed', (
      tester,
    ) async {
      final geometrySource = MockTrailGeometryDataSource();
      final mockLocationCubit = MockLocationCubit();
      final mockPhoneWearSyncService = MockPhoneWearSyncService();

      when(() => mockLocationCubit.state).thenReturn(LocationState.idle());
      when(
        () => mockLocationCubit.stream,
      ).thenAnswer((_) => const Stream<LocationState>.empty());
      when(() => mockLocationCubit.pendingNavigation).thenReturn(false);
      when(() => mockLocationCubit.elapsed).thenReturn(Duration.zero);
      when(() => mockLocationCubit.isRunning).thenReturn(false);
      when(() => mockLocationCubit.setInitialEta(any())).thenReturn(null);
      when(() => mockLocationCubit.setTotalDistance(any())).thenReturn(null);
      when(
        () => mockLocationCubit.setTrailData(
          segments: any(named: 'segments'),
          onOffTrail: any(named: 'onOffTrail'),
        ),
      ).thenReturn(null);
      when(
        () => mockLocationCubit.registerStopCallbacks(
          onActivitySaved: dummyOnActivitySavedCallback,
          onNavigateAfterStop: dummyNavigateAfterStop,
        ),
      ).thenAnswer((_) {});
      when(() => mockLocationCubit.unregisterStopCallbacks()).thenReturn(null);
      when(() => mockLocationCubit.startTracking()).thenAnswer((_) async {});
      when(() => mockLocationCubit.pauseTracking()).thenAnswer((_) async {});
      when(() => mockLocationCubit.resumeTracking()).thenAnswer((_) async {});
      when(
        () => mockLocationCubit.stopAndSave(navigate: any(named: 'navigate')),
      ).thenAnswer((_) async {});
      when(() => mockLocationCubit.consumeNavigation()).thenReturn(null);
      when(() => mockLocationCubit.clearHistory()).thenAnswer((_) async {});
      when(() => mockLocationCubit.close()).thenAnswer((_) async {});
      when(
        () => mockPhoneWearSyncService.sendNavigationPrompt(),
      ).thenAnswer((_) async {});

      if (sl.isRegistered<LocationCubit>()) {
        sl.unregister<LocationCubit>();
      }
      if (sl.isRegistered<PhoneWearSyncService>()) {
        sl.unregister<PhoneWearSyncService>();
      }
      sl.registerSingleton<LocationCubit>(mockLocationCubit);
      sl.registerSingleton<PhoneWearSyncService>(mockPhoneWearSyncService);
      addTearDown(() {
        if (sl.isRegistered<LocationCubit>()) {
          sl.unregister<LocationCubit>();
        }
        if (sl.isRegistered<PhoneWearSyncService>()) {
          sl.unregister<PhoneWearSyncService>();
        }
      });

      const cachedTrail = PlannedTrail(
        activityId: 'act_123',
        trailId: '12345',
        segments: [
          [TrailPoint(lat: 45.1, lng: 9.1), TrailPoint(lat: 45.2, lng: 9.2)],
        ],
      );

      when(
        () => mockActivityCubit.getPlannedTrail('act_123'),
      ).thenAnswer((_) async => cachedTrail);

      await tester.pumpWidget(
        pumpApp(
          activityCubit: mockActivityCubit,
          profileCubit: mockProfileCubit,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 800,
                child: ActivityDetailPage(
                  activity: createDummyActivity(daysFromNow: 20),
                  trailGeometrySource: geometrySource,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigatorScreen), findsOneWidget);
      verify(() => mockActivityCubit.getPlannedTrail('act_123')).called(1);
      verifyNever(() => geometrySource.fetchTrailPath(any()));
    });

    testWidgets('renders header and basic information correctly', (
      tester,
    ) async {
      final activity = createDummyActivity();
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Escursione al Monte Baldo'), findsOneWidget);
      expect(find.text('Sentiero 65'), findsOneWidget);

      expect(find.text('Intermediate'), findsOneWidget);

      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('5.5 km'), findsOneWidget);
    });

    testWidgets('navigates correctly between Overview and Notes tabs', (
      tester,
    ) async {
      final activity = createDummyActivity(daysFromNow: 20);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Overview'), findsOneWidget);
      expect(
        find.text('Forecast available only within 14 days of the hike.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Test notes'), findsOneWidget);
    });

    testWidgets('opens the note dialog from the Notes FAB and saves a note', (
      tester,
    ) async {
      final activity = createDummyActivity();
      when(
        () => mockActivityCubit.addOrUpdateNote(any(), any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest(activity));

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('New Note'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('note_text_field')),
        'Trail felt great today',
      );
      await tester.tap(find.byKey(const ValueKey('save_note_button')));
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockActivityCubit.addOrUpdateNote(any(), captureAny()),
      ).captured;

      expect(captured.first as ActivityNote, isA<ActivityNote>());
      expect((captured.first as ActivityNote).text, 'Trail felt great today');
    });

    testWidgets('edits an existing note from the note card', (tester) async {
      final activity = createDummyActivity();
      when(
        () => mockActivityCubit.addOrUpdateNote(any(), any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest(activity));

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test notes'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Note'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('note_text_field')),
        'Updated note text',
      );
      await tester.tap(find.byKey(const ValueKey('save_note_button')));
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockActivityCubit.addOrUpdateNote(any(), captureAny()),
      ).captured;

      final updatedNote = captured.first as ActivityNote;
      expect(updatedNote.id, 'note_test');
      expect(updatedNote.text, 'Updated note text');
      expect(updatedNote.createdAt, isNotNull);
    });

    testWidgets('deletes an existing note from the note card', (tester) async {
      final activity = createDummyActivity();

      await tester.pumpWidget(createWidgetUnderTest(activity));

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Test notes'));
      await tester.pumpAndSettle();

      expect(find.text('Delete note'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mockActivityCubit.deleteNote(activity, 'note_test')).called(
        1,
      );
    });

    testWidgets('shows stats in Overview tab if activity is completed', (
      tester,
    ) async {
      final activity = createDummyActivity(status: ActivityStatus.completed);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Elevation Gain'), findsOneWidget);
      expect(find.textContaining('400'), findsOneWidget);
      expect(find.text('XP Earned'), findsOneWidget);
      expect(find.textContaining('150'), findsOneWidget);
    });

    testWidgets('shows empty state if notes are empty', (tester) async {
      final activity = createDummyActivity(notes: []);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No notes yet'), findsOneWidget);
    });

    testWidgets('cancels activity deletion from the popup', (tester) async {
      final activity = createDummyActivity();
      await tester.pumpWidget(createWidgetUnderTest(activity));

      final deleteIcon = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteIcon);

      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Are you sure you want to delete this activity?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));

      await tester.pump(const Duration(milliseconds: 500));

      verifyNever(() => mockActivityCubit.deleteActivity(any()));
      expect(find.byType(ActivityDetailPage), findsOneWidget);
    });

    testWidgets('confirms activity deletion from the popup', (tester) async {
      final activity = createDummyActivity();
      await tester.pumpWidget(createWidgetUnderTest(activity));

      await tester.tap(find.byIcon(Icons.delete_outline));

      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Delete'));

      await tester.pump(const Duration(milliseconds: 500));

      verify(() => mockActivityCubit.deleteActivity('act_123')).called(1);
    });

    testWidgets('renders colors and labels for "Easy" difficulty', (
      tester,
    ) async {
      final activity = createDummyActivity(difficulty: ActivityDifficulty.easy);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Beginner'), findsOneWidget);
    });

    testWidgets('renders colors and labels for "Hard" difficulty', (
      tester,
    ) async {
      final activity = createDummyActivity(difficulty: ActivityDifficulty.hard);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Expert'), findsOneWidget);
    });

    testWidgets('does not show trail name if it is empty', (tester) async {
      final activity = createDummyActivity(trailName: '');
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Sentiero 65'), findsNothing);
    });

    testWidgets('hides weather forecast error if activity is not planned', (
      tester,
    ) async {
      final activity = createDummyActivity(status: ActivityStatus.completed);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(
        find.text('Forecast available only within 14 days of the hike.'),
        findsNothing,
      );
    });

    testWidgets(
      'shows loading indicator and then successful weather forecast within 14 days',
      (tester) async {
        HttpOverrides.global = FakeWeatherHttpOverrides(shouldFail: false);

        final activity = createDummyActivity(daysFromNow: 5);
        await tester.pumpWidget(createWidgetUnderTest(activity));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);

        final precipitationFinder = find.text(
          'Precipitation',
          skipOffstage: false,
        );
        final windFinder = find.text('Wind', skipOffstage: false);
        final windSpeedFinder = find.text('15 km/h', skipOffstage: false);
        final tempFinder = find.text('22°', skipOffstage: false);

        expect(precipitationFinder, findsOneWidget);

        await tester.ensureVisible(precipitationFinder);

        await tester.pump(const Duration(milliseconds: 500));

        expect(windFinder, findsOneWidget);
        expect(windSpeedFinder, findsOneWidget);
        expect(tempFinder, findsOneWidget);
      },
    );

    testWidgets('shows weather card error gracefully if HTTP call fails', (
      tester,
    ) async {
      HttpOverrides.global = FakeWeatherHttpOverrides(shouldFail: true);

      final activity = createDummyActivity(daysFromNow: 5);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });
  });
}
