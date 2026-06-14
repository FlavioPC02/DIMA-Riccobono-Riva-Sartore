import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/screens/activity_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockActivityCubit extends Mock implements ActivityCubit {}

class MockGeolocatorPlatform extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.always;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    return Position(
      longitude: 12.0,
      latitude: 41.0,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
}

class FakeWeatherHttpOverrides extends HttpOverrides {
  final bool shouldFail;
  FakeWeatherHttpOverrides({this.shouldFail = false});

  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeWeatherHttpClient(shouldFail);
}

class _FakeWeatherHttpClient extends Fake implements HttpClient {
  final bool shouldFail;
  _FakeWeatherHttpClient(this.shouldFail);

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
  Future<HttpClientResponse> close() async => _FakeWeatherHttpResponse(shouldFail);

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

class _FakeWeatherHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  final bool shouldFail;
  _FakeWeatherHttpResponse(this.shouldFail);

  @override
  int get statusCode => shouldFail ? 500 : 200;

  @override
  int get contentLength => _getBody().length;

  @override
  String get reasonPhrase => shouldFail ? 'Server Error' : 'OK';

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

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
        "wind_speed_10m_max": [15.0]
      },
      "hourly": {
        "time": [
          "${dateStr}T10:00", "${dateStr}T11:00", "${dateStr}T12:00", 
          "${dateStr}T13:00", "${dateStr}T14:00", "${dateStr}T15:00",
          "${dateStr}T16:00", "${dateStr}T17:00"
        ],
        "weather_code": [800, 801, 802, 700, 600, 500, 300, 200], 
        "temperature_2m": [20.0, 21.0, 22.0, 20.0, 18.0, 19.0, 15.0, 14.0],
        "precipitation_probability": [0, 0, 10, 20, 80, 90, 100, 100]
      }
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
      onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockActivityCubit mockActivityCubit;

  setUpAll(() {
    HttpOverrides.global = FakeWeatherHttpOverrides();
  });

  setUp(() {
    GeolocatorPlatform.instance = MockGeolocatorPlatform();

    mockActivityCubit = MockActivityCubit();
    when(() => mockActivityCubit.state).thenReturn([]); 
    when(() => mockActivityCubit.stream).thenAnswer((_) => Stream.empty());
    when(() => mockActivityCubit.deleteActivity(any())).thenAnswer((_) async {});
  });

  Activity createDummyActivity({
    ActivityStatus status = ActivityStatus.planned,
    String notes = 'Test notes',
    ActivityDifficulty difficulty = ActivityDifficulty.moderate,
    int daysFromNow = 5, 
    String trailName = 'Sentiero 65',
  }) {
    return Activity(
      id: 'act_123',
      name: 'Escursione al Monte Baldo',
      trailName: trailName,
      difficulty: difficulty,
      date: DateTime.now().add(Duration(days: daysFromNow)),
      durationMinutes: 120,
      distanceKm: 5.5,
      xpEarned: 150,
      trackedElevationGap: 400,
      trackedDistance: 5.2,
      trackedTime: const Duration(minutes: 125),
      status: status,
      notes: notes,
    );
  }

  Widget createWidgetUnderTest(Activity activity) {
    return MaterialApp(
      home: BlocProvider<ActivityCubit>.value(
        value: mockActivityCubit,
        child: ActivityDetailPage(activity: activity),
      ),
    );
  }

  group('ActivityDetailPage Widget Tests', () {
    testWidgets('renders header and basic information correctly', (tester) async {
      final activity = createDummyActivity();
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Escursione al Monte Baldo'), findsOneWidget);
      expect(find.text('Sentiero 65'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('5.5 km'), findsOneWidget); 
    });

    testWidgets('navigates correctly between Overview, Stats, and Notes tabs', (tester) async {
      final activity = createDummyActivity(daysFromNow: 20);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Forecast available only within 14 days of the hike.'), findsOneWidget);

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle(); 

      expect(find.text('Elevation Gain'), findsOneWidget);
      expect(find.textContaining('400'), findsOneWidget);
      expect(find.text('XP Earned'), findsOneWidget);
      expect(find.textContaining('150'), findsOneWidget);

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Test notes'), findsOneWidget);
    });

    testWidgets('shows empty state if notes are empty', (tester) async {
      final activity = createDummyActivity(notes: '');
      await tester.pumpWidget(createWidgetUnderTest(activity));

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.text('No notes yet.'), findsOneWidget);
    });

    testWidgets('cancels activity deletion from the popup', (tester) async {
      final activity = createDummyActivity();
      await tester.pumpWidget(createWidgetUnderTest(activity));

      final deleteIcon = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteIcon);
      
      await tester.pump(const Duration(milliseconds: 500)); 

      expect(find.text('Are you sure you want to delete this activity?'), findsOneWidget);

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
    
    testWidgets('renders colors and labels for "Easy" difficulty', (tester) async {
      final activity = createDummyActivity(difficulty: ActivityDifficulty.easy);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Easy'), findsOneWidget);
    });

    testWidgets('renders colors and labels for "Hard" difficulty', (tester) async {
      final activity = createDummyActivity(difficulty: ActivityDifficulty.hard);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('does not show trail name if it is empty', (tester) async {
      final activity = createDummyActivity(trailName: '');
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Sentiero 65'), findsNothing);
    });

    testWidgets('hides weather forecast error if activity is not planned', (tester) async {
      final activity = createDummyActivity(status: ActivityStatus.completed);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.text('Forecast available only within 14 days of the hike.'), findsNothing);
    });

    testWidgets('shows loading indicator and then successful weather forecast within 14 days', (tester) async {
      HttpOverrides.global = FakeWeatherHttpOverrides(shouldFail: false);
      
      final activity = createDummyActivity(daysFromNow: 5);
      await tester.pumpWidget(createWidgetUnderTest(activity));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pump(const Duration(seconds: 1)); 
      await tester.pump();
      
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final precipitationFinder = find.text('Precipitation', skipOffstage: false);
      final windFinder = find.text('Wind', skipOffstage: false);
      final windSpeedFinder = find.text('15 km/h', skipOffstage: false);
      final tempFinder = find.text('22°', skipOffstage: false);

      expect(precipitationFinder, findsOneWidget);

      await tester.ensureVisible(precipitationFinder);
      
      await tester.pump(const Duration(milliseconds: 500));

      expect(windFinder, findsOneWidget);
      expect(windSpeedFinder, findsOneWidget);
      expect(tempFinder, findsOneWidget);
    });
    
    testWidgets('shows weather card error gracefully if HTTP call fails', (tester) async {
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