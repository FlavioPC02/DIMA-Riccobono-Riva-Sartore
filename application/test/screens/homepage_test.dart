import 'dart:io';
import 'package:application/screens/diary_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/settings.dart';
import 'package:application/core/models/profile.dart';
import 'package:application/services/helpers/notification_permission_helper.dart';
import 'package:application/screens/homepage.dart';
import 'package:application/screens/profile_screen.dart';
import 'package:application/screens/map_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 
import '../utils/pump_app.dart';
import '../mocks/mocks_manual.dart';
import '../utils/map_test_helper.dart';

class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {}
class MockAndroidFlutterLocalNotificationsPlugin extends Mock implements AndroidFlutterLocalNotificationsPlugin {}

void main() {
  late MockSettingsCubit mockSettingsCubit;
  late MockProfileCubit mockProfileCubit;
  late MockActivityCubit mockActivityCubit;
  
  late MockFlutterLocalNotificationsPlugin mockNotificationPlugin;
  late MockAndroidFlutterLocalNotificationsPlugin mockAndroidNotificationPlugin;

  void mockNotificationPermission(bool granted) {
    when(() => mockNotificationPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
        .thenReturn(mockAndroidNotificationPlugin);
    
    when(() => mockAndroidNotificationPlugin.requestNotificationsPermission())
        .thenAnswer((_) async => granted);
        
    when(() => mockAndroidNotificationPlugin.areNotificationsEnabled())
        .thenAnswer((_) async => granted);
  }

  setUpAll(() async {
    const envString = '''MAPBOX_ACCESS_TOKEN=test_token_123''';
    dotenv.loadFromString(envString: envString);
    HttpOverrides.global = FakeHttpOverrides();
  });

  setUp(() {
    GeolocatorPlatform.instance = MockGeolocatorPlatform();

    mockNotificationPlugin = MockFlutterLocalNotificationsPlugin();
    mockAndroidNotificationPlugin = MockAndroidFlutterLocalNotificationsPlugin();
    NotificationPermissionHelper.plugin = mockNotificationPlugin;
    NotificationPermissionHelper.mockIsAndroid = true; 
    NotificationPermissionHelper.mockIsIOS = false;

    mockSettingsCubit = MockSettingsCubit();
    mockProfileCubit = MockProfileCubit();
    mockActivityCubit = MockActivityCubit();

    when(() => mockSettingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockSettingsCubit.state).thenReturn(
      Settings(
        notifications: true,
        ferrata: true,
        difficulty: 0.5,
      ),
    );

    when(() => mockProfileCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockProfileCubit.state).thenReturn(
      Profile(
        nickname: 'test_user', 
        mail: 'test@mail.it', 
        xp: 0.50,
        level: 1,
      ),
    );

    when(() => mockActivityCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockActivityCubit.state).thenReturn(const <Activity>[]);

    mockNotificationPermission(true);
  });

  tearDown(() {
    NotificationPermissionHelper.mockIsAndroid = null;
    NotificationPermissionHelper.mockIsIOS = null;
  });

  group('Navigation Widget Tests', () {
    
    testWidgets('Initial state should render MapPage and NavigationBar items', (WidgetTester tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const Navigation(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Diary'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      expect(find.byType(MapPage), findsOneWidget);
      
      await tearDownMap(tester);
    });

    testWidgets('Tapping on Diary tab switches to DiaryPage', (WidgetTester tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const Navigation(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Diary'));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryPage), findsOneWidget);
      expect(find.text('Diary'), findsWidgets); 
      
      await tearDownMap(tester);
    });

    testWidgets('Tapping on Profile tab switches to SettingsPage/ProfilePage', (WidgetTester tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const Navigation(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ProfilePage), findsOneWidget);
      
      await tearDownMap(tester);
    });
  });

  group('Standalone Pages Tests', () {
    testWidgets('DiaryPage renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const DiaryPage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );
      
      expect(find.text('Diary'), findsOneWidget);
      expect(find.textContaining('No completed hikes yet'), findsOneWidget);
    });

    testWidgets('SettingsPage renders ProfilePage', (WidgetTester tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const SettingsPage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );
      
      expect(find.byType(ProfilePage), findsOneWidget);
    });
  });

  group('Notification Permission Dialog Tests', () {
    testWidgets('Notification permission dialog is shown when permission is denied', (WidgetTester tester) async {
      mockNotificationPermission(false);
      
      await tester.pumpWidget(
        pumpApp(
          child: const Navigation(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );
      
      await tester.pumpAndSettle();

      expect(find.text('Notification permission required'), findsOneWidget);
      expect(find.textContaining('Without enabling the permission'), findsOneWidget);
      
      await tearDownMap(tester);
    });

    testWidgets('Dialog "Enable notification permission" button is functional', (WidgetTester tester) async {
      mockNotificationPermission(false);
      
      await tester.pumpWidget(
        pumpApp(
          child: const Navigation(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );
      
      await tester.pumpAndSettle();

      expect(find.text('Enable notification permission'), findsOneWidget);
      await tester.tap(find.text('Enable notification permission'));
      await tester.pumpAndSettle();

      expect(find.text('Notification permission required'), findsNothing);
      
      await tearDownMap(tester);
    });

    testWidgets('Dialog "Ignore" button closes the dialog', (WidgetTester tester) async {
      mockNotificationPermission(false);
      
      await tester.pumpWidget(
        pumpApp(
          child: const Navigation(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );
      
      await tester.pumpAndSettle();

      expect(find.text('Ignore'), findsOneWidget);
      await tester.tap(find.text('Ignore'));
      await tester.pumpAndSettle();

      expect(find.text('Notification permission required'), findsNothing);
      
      await tearDownMap(tester);
    });
  });
}