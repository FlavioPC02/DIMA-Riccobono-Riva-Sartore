import 'dart:async';
import 'dart:io';

import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/location_point.dart';
import 'package:application/core/models/profile.dart';
import 'package:application/core/models/settings.dart';
import 'package:application/screens/navigator.dart';
import 'package:application/services/phone_wear_sync.dart';
import 'package:application/widgets/stats_recording_card.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:get_it/get_it.dart';
import 'package:hike_core/hike_core.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../mocks/mocks_manual.dart';
import '../utils/map_test_helper.dart';
import '../utils/pump_app.dart';
import '../utils/test_config.dart';

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

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

void main() {
  late MockLocationCubit mockLocationCubit;
  late MockActivityCubit mockActivityCubit;
  late MockProfileCubit mockProfileCubit;
  late MockSettingsCubit mockSettingsCubit;
  late MockGeolocatorPlatform mockGeolocator;
  late MockPhoneWearSyncService mockPhoneWearSyncService;

  final Map<String, dynamic> dummyTrail = {
    'name': 'Sentiero Test Navigator',
    'subTrails': [
      [const LatLng(41.9028, 12.4964), const LatLng(45.4642, 9.1900)],
    ],
  };

  Activity createDummyActivity({String id = ''}) {
    return Activity(
      id: id,
      name: 'Hike',
      status: ActivityStatus.planned,
      date: DateTime.now(),
      trailName: 'Sentiero Test Navigator',
      distanceKm: 5.0,
      durationMinutes: 120,
      xpEarned: 100,
      notes: [],
      difficulty: ActivityDifficulty.moderate,
      trackedDistance: 0,
      trackedElevationGap: 0,
      trackedTime: Duration.zero,
    );
  }

  setUpAll(() {
    const envString = '''MAPBOX_ACCESS_TOKEN=test_token_123''';
    dotenv.loadFromString(envString: envString);
    HttpOverrides.global = FakeHttpOverrides();

    registerAllFallbacks();
    registerFallbackValue(FakeActivity());
    registerFallbackValue(dummyOnActivitySavedCallback);
    registerFallbackValue(dummyNavigateAfterStop);

    setupTest();
  });

  setUp(() {
    mockLocationCubit = MockLocationCubit();
    mockActivityCubit = MockActivityCubit();
    mockProfileCubit = MockProfileCubit();
    mockSettingsCubit = MockSettingsCubit();
    mockGeolocator = MockGeolocatorPlatform();
    mockPhoneWearSyncService = MockPhoneWearSyncService();

    GeolocatorPlatform.instance = mockGeolocator;
    when(
      () => mockGeolocator.isLocationServiceEnabled(),
    ).thenAnswer((_) async => true);
    when(
      () => mockGeolocator.checkPermission(),
    ).thenAnswer((_) async => LocationPermission.always);
    when(
      () => mockGeolocator.getServiceStatusStream(),
    ).thenAnswer((_) => const Stream.empty());

    final dummyPosition = Position(
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
    );

    when(
      () => mockGeolocator.getLastKnownPosition(),
    ).thenAnswer((_) async => dummyPosition);

    when(
      () => mockGeolocator.getCurrentPosition(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenAnswer((_) async => dummyPosition);

    when(
      () => mockGeolocator.getPositionStream(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenAnswer((_) => const Stream.empty());

    final getIt = GetIt.instance;
    getIt.allowReassignment = true;

    when(
      () => mockLocationCubit.stream,
    ).thenAnswer((_) => const Stream.empty());

    when(() => mockLocationCubit.state).thenReturn(
      LocationState.tracking(
        points: const [],
        current: LocationPoint(
          lat: 41.8900,
          lng: 12.4900,
          altitude: 0,
          positionAccuracy: 5,
          altitudeAccuracy: 5,
          timestamp: DateTime.now(),
        ),
        distance: 0,
        elevationGap: 0,
        totalAscent: 0,
        totalDescent: 0,
      ),
    );
    whenListen<LocationState>(
      mockLocationCubit,
      const Stream<LocationState>.empty(),
      initialState: const LocationState.idle(),
    );
    when(() => mockLocationCubit.elapsed).thenReturn(Duration.zero);
    when(() => mockLocationCubit.isRunning).thenReturn(false);
    when(() => mockLocationCubit.pendingNavigation).thenReturn(false);
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
      () => mockActivityCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockActivityCubit.state).thenReturn([]);
    when(
      () => mockActivityCubit.addActivity(any()),
    ).thenAnswer((_) async => 'new_id');
    when(
      () => mockActivityCubit.updateActivity(any()),
    ).thenAnswer((_) async {});

    when(() => mockProfileCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockProfileCubit.state).thenReturn(
      Profile(nickname: 'Test', mail: 'test@mail.com', xp: 50, level: 1),
    );
    when(() => mockProfileCubit.updateXp(any())).thenReturn(null);

    when(
      () => mockSettingsCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockSettingsCubit.state).thenReturn(
      Settings(notifications: true, ferrata: false, difficulty: 1.0),
    );

    when(
      () => mockPhoneWearSyncService.sendNavigationPrompt(),
    ).thenAnswer((_) async {});

    //Register mocks in service locator
    if (getIt.isRegistered<LocationCubit>()) getIt.unregister<LocationCubit>();
    if (getIt.isRegistered<PhoneWearSyncService>()) {
      getIt.unregister<PhoneWearSyncService>();
    }
    getIt.registerSingleton<LocationCubit>(mockLocationCubit);
    getIt.registerSingleton<PhoneWearSyncService>(mockPhoneWearSyncService);
  });

  tearDownAll(() {
    GetIt.instance.reset();
    HttpOverrides.global = null;
  });

  Widget createWidgetUnderTest(Activity activity) {
    return pumpApp(
      activityCubit: mockActivityCubit,
      profileCubit: mockProfileCubit,
      settingsCubit: mockSettingsCubit,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: NavigatorScreen(trail: dummyTrail, activity: activity),
          ),
        ),
      ),
    );
  }

  group('NavigatorScreen initialization', () {
    testWidgets('LocationCubit configuration', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();

      final totalDuration = createDummyActivity().durationMinutes;
      final totalDistanceMeters = createDummyActivity().distanceKm * 1000;

      verify(
        () => mockLocationCubit.setInitialEta(Duration(minutes: totalDuration)),
      ).called(1);
      verify(
        () => mockLocationCubit.setTotalDistance(totalDistanceMeters),
      ).called(1);
      verify(
        () => mockLocationCubit.setTrailData(
          segments: any(named: 'segments'),
          onOffTrail: any(named: 'onOffTrail'),
        ),
      ).called(1);
    });

    testWidgets('register stop callbacks on the cubit', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();

      final captured = verify(
        () => mockLocationCubit.registerStopCallbacks(
          onActivitySaved: captureAny(named: 'onActivitySaved'),
          onNavigateAfterStop: captureAny(named: 'onNavigateAfterStop'),
        ),
      ).captured;

      expect(captured[0], isA<OnActivitySavedCallback>());
      expect(captured[1], isA<OnNavigateAfterStop>());
    });

    testWidgets('send navigation prompt to the watch on init', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();

      verify(() => mockPhoneWearSyncService.sendNavigationPrompt()).called(1);
    });

    testWidgets('starts tracking on init', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();

      verify(() => mockLocationCubit.startTracking());
    });

    testWidgets(
      'consumes pending navigation on first frame if cubit reports it',
      (tester) async {
        when(() => mockLocationCubit.pendingNavigation).thenReturn(true);

        await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
        await tester.pumpAndSettle();

        verify(
          () => mockLocationCubit.consumeNavigation(),
        ).called(greaterThanOrEqualTo(1));
      },
    );
  });

  group('NavigatorScreen Lifecycle', () {
    testWidgets('calls consumeNavigation when app resumes', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();

      //Simulate app resuming
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(
        () => mockLocationCubit.consumeNavigation(),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('on dispose unregister callbacks and closes cubit', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();

      //Replace with empty widget to simulate closing the screen
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      verify(() => mockLocationCubit.unregisterStopCallbacks()).called(1);
      verify(() => mockLocationCubit.close()).called(1);
    });

    testWidgets('calls stopAndSave on back', (tester) async {
      //Enclose widget under test to simulate back button
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        createWidgetUnderTest(createDummyActivity()),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      //Push NavigatorScreen
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigatorScreen), findsOneWidget);

      //Pop the screen
      Navigator.of(tester.element(find.byType(NavigatorScreen))).pop();
      await tester.pumpAndSettle();

      verify(() => mockLocationCubit.stopAndSave(navigate: true)).called(1);
    });
  });

  group('NavigatorScreen Recording Controls', () {
    testWidgets('tapping pause button pauses tracking', (
      tester,
    ) async {
      when(() => mockLocationCubit.isRunning).thenReturn(true);

      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pumpAndSettle();

      await tester.drag(
        find.text('Sentiero Test Navigator'),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pause'));
      await tester.pump();

      verify(() => mockLocationCubit.pauseTracking()).called(1);
    });

    testWidgets('tapping resume button resumes tracking', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pumpAndSettle();

      await tester.drag(
        find.text('Sentiero Test Navigator'),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);

      await tester.tap(find.text('Resume'));
      await tester.pump();

      verify(() => mockLocationCubit.resumeTracking()).called(1);
    });

    testWidgets('tapping stop button stops the tracking', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();

      await tester.drag(
        find.text('Sentiero Test Navigator'),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      final stopButton = find.text('Stop');
      expect(stopButton, findsOneWidget);

      await tester.tap(stopButton);
      await tester.pump();

      verify(() => mockLocationCubit.stopAndSave(navigate: true)).called(1);
    });
  });

  group('NavigatorScreen on stop callbacks', () {
    testWidgets('onActivitySaved updates and persists activity', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();

      final captured = verify(() => mockLocationCubit.registerStopCallbacks(
        onActivitySaved: captureAny(named: 'onActivitySaved'), 
        onNavigateAfterStop: any(named: 'onNavigateAfterStop'),
      )).captured;

      final onActivitySaved = captured.first as OnActivitySaved;
      await onActivitySaved(
        distance: 4200.0,
        elevationGap: 150.0,
        elapsed: const Duration(minutes: 42),
      );

      //new activity => call addActivity
      verify(() => mockActivityCubit.addActivity(any())).called(1);
      verifyNever(() => mockActivityCubit.updateActivity(any()));

      verify(() => mockProfileCubit.updateXp(any())).called(1);
    });

    testWidgets('stops recording and updates an existing activity', (
      tester,
    ) async {
      final existingActivity = createDummyActivity(id: 'existing_id');
      await tester.pumpWidget(createWidgetUnderTest(existingActivity));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(() => mockLocationCubit.registerStopCallbacks(
        onActivitySaved: captureAny(named: 'onActivitySaved'), 
        onNavigateAfterStop: any(named: 'onNavigateAfterStop'),
      )).captured;

      final onActivitySaved = captured.first as OnActivitySaved;
      await onActivitySaved(
        distance: 4200.0,
        elevationGap: 150.0,
        elapsed: const Duration(minutes: 42),
      );

      //existing activity => call updateActivity
      final savedActivity = verify(
        () => mockActivityCubit.updateActivity(captureAny()),
      ).captured.single as Activity;
      verifyNever(() => mockActivityCubit.addActivity(any()));

      expect(savedActivity.status, ActivityStatus.completed);
      expect(savedActivity.trackedDistance, 4200.0);
      expect(savedActivity.trackedElevationGap, 150.0);
      expect(savedActivity.trackedTime, const Duration(minutes: 42));
      expect(existingActivity.status, ActivityStatus.planned);

      verify(() => mockProfileCubit.updateXp(any())).called(1);
    });

    testWidgets('onNavigateAfterStops pops NavigatorScreen', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();

      final captured = verify(() => mockLocationCubit.registerStopCallbacks(
        onActivitySaved: any(named: 'onActivitySaved'), 
        onNavigateAfterStop: captureAny(named: 'onNavigateAfterStop'),
      )).captured;

      final onNavigateAfterStop = captured.first as OnNavigateAfterStop;

      onNavigateAfterStop();
      await tester.pumpAndSettle();

      //Navigator screen no longer present
      expect(find.byType(NavigatorScreen), findsNothing);
    });
  });

  group('NavigatorScreen Widget Tests', () {
    testWidgets('renders map and initial collapsed sheet correctly', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Sentiero Test Navigator'), findsOneWidget);
      expect(find.byType(StatsRecordingCard), findsOneWidget);
      //Collapsed stats sheet
      expect(find.byKey(const ValueKey('expanded-stats')), findsNothing);
      verify(() => mockLocationCubit.startTracking()).called(1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('drags up bottom sheet to reveal recording controls', (
      tester,
    ) async {
      when(() => mockLocationCubit.isRunning).thenReturn(true);

      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.drag(
        find.text('Sentiero Test Navigator'),
        const Offset(0, -400),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const ValueKey('expanded-stats')), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Elevation Gap'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('centers map on user when FAB is pressed', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);

      await tester.tap(fabFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('updates displayed time as timer ticks', (tester) async {
      var elapsed = Duration.zero;
      when(() => mockLocationCubit.elapsed).thenAnswer((_) => elapsed);

      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
      await tester.pump();

      // Simulate the cubit's stopwatch advancing past a second boundary.
      elapsed = const Duration(seconds: 1, milliseconds: 50);
      await tester.pump(const Duration(milliseconds: 150));

      await tester.drag(
        find.text('Sentiero Test Navigator'),
        const Offset(0, -400),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(elapsed.toCompactLabel()), findsOneWidget);
    });
  });
}
