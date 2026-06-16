//import 'dart:async';
//import 'dart:io';
//
//import 'package:application/core/cubit/location_cubit.dart';
//import 'package:application/core/models/activity.dart';
//import 'package:application/core/models/location_point.dart';
//import 'package:application/core/models/profile.dart';
//import 'package:application/core/models/settings.dart';
//import 'package:application/screens/navigator.dart'; 
//import 'package:application/services/notification_service.dart';
//import 'package:flutter/material.dart';
//import 'package:flutter_dotenv/flutter_dotenv.dart';
//import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//import 'package:flutter_map/flutter_map.dart';
//import 'package:flutter_test/flutter_test.dart';
//import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
//import 'package:get_it/get_it.dart';
//import 'package:latlong2/latlong.dart';
//import 'package:mocktail/mocktail.dart';
//import 'package:plugin_platform_interface/plugin_platform_interface.dart';
//
//import '../mocks/mocks_manual.dart';
//import '../utils/map_test_helper.dart';
//import '../utils/pump_app.dart';
//
//class TestFlutterLocalNotificationsPlugin extends Fake implements FlutterLocalNotificationsPlugin {
//  int showCallCount = 0;
//  String? lastTitle;
//  String? lastBody;
//
//  @override
//  Future<void> show({
//    required int id,
//    String? title,
//    String? body,
//    NotificationDetails? notificationDetails,
//    String? payload,
//  }) async {
//    showCallCount++;
//    lastTitle = title;
//    lastBody = body;
//  }
//}
//
//class FakeNotificationDetails extends Fake implements NotificationDetails {}
//class MockLocationCubit extends Mock implements LocationCubit {}
//class MockGeolocatorPlatform extends Mock with MockPlatformInterfaceMixin implements GeolocatorPlatform {}
//
//void main() {
//  late MockLocationCubit mockLocationCubit;
//  late MockActivityCubit mockActivityCubit;
//  late MockProfileCubit mockProfileCubit;
//  late MockSettingsCubit mockSettingsCubit;
//  late TestFlutterLocalNotificationsPlugin mockNotificationPlugin;
//  late MockGeolocatorPlatform mockGeolocator;
//
//  final Map<String, dynamic> dummyTrail = {
//    'name': 'Sentiero Test Navigator',
//    'subTrails': [
//      [const LatLng(41.9028, 12.4964), const LatLng(45.4642, 9.1900)]
//    ]
//  };
//
//  Activity createDummyActivity({String id = ''}) {
//    return Activity(
//      id: id,
//      name: 'Hike',
//      status: ActivityStatus.planned,
//      date: DateTime.now(),
//      trailName: 'Sentiero Test Navigator',
//      distanceKm: 5.0,
//      durationMinutes: 120,
//      xpEarned: 100,
//      notes: '',
//      difficulty: ActivityDifficulty.moderate,
//      trackedDistance: 0,
//      trackedElevationGap: 0,
//      trackedTime: Duration.zero,
//    );
//  }
//
//  setUpAll(() {
//    const envString = '''MAPBOX_ACCESS_TOKEN=test_token_123''';
//    dotenv.loadFromString(envString: envString);
//    HttpOverrides.global = FakeHttpOverrides();
//
//    registerFallbackValue(FakeActivity());
//    registerFallbackValue(FakeNotificationDetails());
//  });
//
//  setUp(() { 
//    mockLocationCubit = MockLocationCubit();
//    mockActivityCubit = MockActivityCubit();
//    mockProfileCubit = MockProfileCubit();
//    mockSettingsCubit = MockSettingsCubit();
//    mockNotificationPlugin = TestFlutterLocalNotificationsPlugin();
//    NotificationService.plugin = mockNotificationPlugin;
//    mockGeolocator = MockGeolocatorPlatform();
//
//    GeolocatorPlatform.instance = mockGeolocator;
//    when(() => mockGeolocator.isLocationServiceEnabled()).thenAnswer((_) async => true);
//    when(() => mockGeolocator.checkPermission()).thenAnswer((_) async => LocationPermission.always);
//    when(() => mockGeolocator.getServiceStatusStream()).thenAnswer((_) => const Stream.empty());
//
//    final dummyPosition = Position(
//      longitude: 12.4900,
//      latitude: 41.8900,
//      timestamp: DateTime.now(),
//      accuracy: 10.0,
//      altitude: 0.0,
//      altitudeAccuracy: 0.0,
//      heading: 0.0,
//      headingAccuracy: 0.0,
//      speed: 0.0,
//      speedAccuracy: 0.0,
//    );
//
//    when(() => mockGeolocator.getLastKnownPosition())
//        .thenAnswer((_) async => dummyPosition);
//    
//    when(() => mockGeolocator.getCurrentPosition(
//        locationSettings: any(named: 'locationSettings')
//    )).thenAnswer((_) async => dummyPosition);
//
//    when(() => mockGeolocator.getPositionStream(
//        locationSettings: any(named: 'locationSettings'),
//    )).thenAnswer((_) => const Stream.empty());
//
//    final getIt = GetIt.instance;
//    getIt.allowReassignment = true;
//    getIt.registerSingleton<LocationCubit>(mockLocationCubit);
//
//    NotificationService.plugin = mockNotificationPlugin;
//    NotificationService.mockPermissionCheck = () async => true;
//
//    when(() => mockLocationCubit.stream).thenAnswer((_) => const Stream.empty());
//    
//    when(() => mockLocationCubit.state).thenReturn(
//      LocationState.tracking(
//        points: const [],
//        current: LocationPoint(lat: 41.8900, lng: 12.4900, altitude: 0, positionAccuracy: 5, altitudeAccuracy: 5, timestamp: DateTime.now()),
//        distance: 0,
//        elevationGap: 0,
//        totalAscent: 0,
//        totalDescent: 0,
//      )
//    );
//    when(() => mockLocationCubit.startTracking()).thenAnswer((_) async {});
//    when(() => mockLocationCubit.stopAndSave()).thenAnswer((_) async {});
//    when(() => mockLocationCubit.clearHistory()).thenAnswer((_) async {});
//    when(() => mockLocationCubit.close()).thenAnswer((_) async {});
//
//    when(() => mockActivityCubit.stream).thenAnswer((_) => const Stream.empty());
//    when(() => mockActivityCubit.state).thenReturn([]);
//    when(() => mockActivityCubit.addActivity(any())).thenAnswer((_) async => 'new_id');
//    when(() => mockActivityCubit.updateActivity(any())).thenAnswer((_) async {});
//
//    when(() => mockProfileCubit.stream).thenAnswer((_) => const Stream.empty());
//    when(() => mockProfileCubit.state).thenReturn(Profile(nickname: 'Test', mail: 'test@mail.com', xp: 50, level: 1));
//    when(() => mockProfileCubit.updateXp(any())).thenReturn(null);
//
//    when(() => mockSettingsCubit.stream).thenAnswer((_) => const Stream.empty());
//    when(() => mockSettingsCubit.state).thenReturn(Settings(notifications: true, ferrata: false, difficulty: 1.0));
//  });
//
//  tearDownAll(() {
//    GetIt.instance.reset();
//    HttpOverrides.global = null;
//  });
//
//  Widget createWidgetUnderTest(Activity activity) {
//    return pumpApp(
//      activityCubit: mockActivityCubit,
//      profileCubit: mockProfileCubit,
//      settingsCubit: mockSettingsCubit,
//      child: MaterialApp(
//        home: Scaffold(
//          body: SizedBox(
//            width: 400,
//            height: 800,
//            child: NavigatorScreen(
//              trail: dummyTrail,
//              activity: activity,
//            ),
//          ),
//        ),
//      ),
//    );
//  }
//
//  group('NavigatorScreen Widget Tests', () {
//    testWidgets('renders map and initial collapsed sheet correctly', (tester) async {
//      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      expect(find.byType(FlutterMap), findsOneWidget);
//      expect(find.text('Sentiero Test Navigator'), findsOneWidget);
//      expect(find.byKey(const ValueKey('expanded-stats')), findsNothing);
//      verify(() => mockLocationCubit.startTracking()).called(1);
//
//      await tester.pumpWidget(const SizedBox()); 
//    });
//
//    testWidgets('drags up bottom sheet to reveal recording controls', (tester) async {
//      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      await tester.drag(find.text('Sentiero Test Navigator'), const Offset(0, -400));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      expect(find.byKey(const ValueKey('expanded-stats')), findsOneWidget);
//      expect(find.text('Distance'), findsOneWidget);
//      expect(find.text('Elevation Gap'), findsOneWidget);
//      expect(find.widgetWithText(ElevatedButton, 'Pause'), findsOneWidget);
//      expect(find.widgetWithText(ElevatedButton, 'Stop'), findsOneWidget);
//
//      await tester.pumpWidget(const SizedBox()); 
//    });
//
//    testWidgets('toggles pause and resume stopwatch', (tester) async {
//      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      await tester.drag(find.text('Sentiero Test Navigator'), const Offset(0, -400));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      final pauseButton = find.widgetWithText(ElevatedButton, 'Pause');
//      await tester.tap(pauseButton);
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      expect(find.widgetWithText(ElevatedButton, 'Resume'), findsOneWidget);
//      expect(find.widgetWithText(ElevatedButton, 'Pause'), findsNothing);
//      verify(() => mockLocationCubit.stopAndSave()).called(1);
//
//      final resumeButton = find.widgetWithText(ElevatedButton, 'Resume');
//      await tester.tap(resumeButton);
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      expect(find.widgetWithText(ElevatedButton, 'Pause'), findsOneWidget);
//      verify(() => mockLocationCubit.startTracking()).called(greaterThan(1));
//
//      await tester.pumpWidget(const SizedBox()); 
//    });
//
//    testWidgets('stops recording and saves a new activity', (tester) async {
//      final newActivity = createDummyActivity(id: '');
//      await tester.pumpWidget(createWidgetUnderTest(newActivity));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      await tester.drag(find.text('Sentiero Test Navigator'), const Offset(0, -400));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop'));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      verify(() => mockLocationCubit.stopAndSave()).called(2);
//      verify(() => mockLocationCubit.clearHistory()).called(1);
//
//      verify(() => mockActivityCubit.addActivity(any())).called(1);
//      verifyNever(() => mockActivityCubit.updateActivity(any()));
//
//      verify(() => mockProfileCubit.updateXp(150)).called(1);
//
//      expect(find.byType(NavigatorScreen), findsNothing);
//
//      await tester.pumpWidget(const SizedBox()); 
//    });
//
//    testWidgets('stops recording and updates an existing activity', (tester) async {
//      final existingActivity = createDummyActivity(id: 'existing_id'); 
//      await tester.pumpWidget(createWidgetUnderTest(existingActivity));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      await tester.drag(find.text('Sentiero Test Navigator'), const Offset(0, -400));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop'));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      verify(() => mockActivityCubit.updateActivity(any())).called(1);
//      verifyNever(() => mockActivityCubit.addActivity(any()));
//
//      await tester.pumpWidget(const SizedBox()); 
//    });
//
//    testWidgets('centers map on user when FAB is pressed', (tester) async {
//      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      final fabFinder = find.byType(FloatingActionButton);
//      expect(fabFinder, findsOneWidget);
//
//      await tester.tap(fabFinder);
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      await tester.pumpWidget(const SizedBox()); 
//    });
//
//    testWidgets('triggers off-trail notification when user is far from path', (tester) async {
//      final streamController = StreamController<LocationState>.broadcast();
//      when(() => mockLocationCubit.stream).thenAnswer((_) => streamController.stream);
//
//      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      final farPoint = LocationPoint(
//        lat: 45.0,
//        lng: 9.0,
//        altitude: 100,
//        positionAccuracy: 5,
//        altitudeAccuracy: 5,
//        timestamp: DateTime.now(),
//      );
//
//      streamController.add(LocationState.tracking(
//        points: [farPoint],
//        current: farPoint,
//        distance: 0,
//        elevationGap: 0,
//        totalAscent: 0,
//        totalDescent: 0,
//      ));
//      
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      expect(mockNotificationPlugin.showCallCount, 1, reason: 'Il metodo show doveva essere chiamato 1 volta');
//      expect(mockNotificationPlugin.lastTitle, 'Out of trail');
//      expect(mockNotificationPlugin.lastBody, contains('You are'));
//
//      await streamController.close();
//      await tester.pumpWidget(const SizedBox()); 
//    });
//
//    testWidgets('updates ETA calculation when user is moving', (tester) async {
//      final streamController = StreamController<LocationState>.broadcast();
//      when(() => mockLocationCubit.stream).thenAnswer((_) => streamController.stream);
//
//      await tester.pumpWidget(createWidgetUnderTest(createDummyActivity()));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      await tester.drag(find.text('Sentiero Test Navigator'), const Offset(0, -400));
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      final t1 = DateTime.now().subtract(const Duration(seconds: 10));
//      final p1 = LocationPoint(lat: 41.8900, lng: 12.4900, altitude: 0, positionAccuracy: 5, altitudeAccuracy: 5, timestamp: t1);
//      final p2 = LocationPoint(lat: 41.8950, lng: 12.4950, altitude: 0, positionAccuracy: 5, altitudeAccuracy: 5, timestamp: DateTime.now());
//
//      streamController.add(LocationState.tracking(
//        points: [p1, p2],
//        current: p2,
//        distance: 500,
//        elevationGap: 0,
//        totalAscent: 0,
//        totalDescent: 0,
//      ));
//
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      expect(find.text('ETA'), findsOneWidget);
//
//      await streamController.close();
//      await tester.pumpWidget(const SizedBox()); 
//    });
//  });
//}