import 'dart:async';
import 'dart:io';
import 'package:application/core/cubit/map_cubit.dart';
import 'package:application/core/cubit/navigation_index_cubit.dart';
import 'package:application/screens/diary_page.dart';
import 'package:application/screens/favorites_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../utils/test_config.dart';

void main() {
  late MockSettingsCubit mockSettingsCubit;
  late MockProfileCubit mockProfileCubit;
  late MockActivityCubit mockActivityCubit;
  late MockNavigationIndexCubit mockNavigationIndexCubit;
  late MockMapCubit mockMapCubit;
  late MockFavoriteTrailStore mockFavoriteTrailStore;
  late StreamController<User?> authController;

  late MockFlutterLocalNotificationsPlugin mockNotificationPlugin;
  late MockAndroidFlutterLocalNotificationsPlugin mockAndroidNotificationPlugin;

  void mockNotificationPermission(bool granted) {
    when(
      () => mockNotificationPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(mockAndroidNotificationPlugin);

    when(
      () => mockAndroidNotificationPlugin.requestNotificationsPermission(),
    ).thenAnswer((_) async => granted);

    when(
      () => mockAndroidNotificationPlugin.areNotificationsEnabled(),
    ).thenAnswer((_) async => granted);
  }

  setUpAll(() async {
    setupTest();
    const envString = '''MAPBOX_ACCESS_TOKEN=test_token_123''';
    dotenv.loadFromString(envString: envString);
    HttpOverrides.global = FakeHttpOverrides();
  });

  setUp(() {
    GeolocatorPlatform.instance = MockGeolocatorPlatform();

    mockNotificationPlugin = MockFlutterLocalNotificationsPlugin();
    mockAndroidNotificationPlugin =
        MockAndroidFlutterLocalNotificationsPlugin();
    NotificationPermissionHelper.plugin = mockNotificationPlugin;
    NotificationPermissionHelper.mockIsAndroid = true;
    NotificationPermissionHelper.mockIsIOS = false;

    mockSettingsCubit = MockSettingsCubit();
    mockProfileCubit = MockProfileCubit();
    mockActivityCubit = MockActivityCubit();
    mockNavigationIndexCubit = MockNavigationIndexCubit();
    mockMapCubit = MockMapCubit();

    mockFavoriteTrailStore = MockFavoriteTrailStore();
    authController = StreamController<User?>();

    when(
      () => mockSettingsCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockSettingsCubit.state,
    ).thenReturn(Settings(notifications: true, ferrata: true, difficulty: 0.5));
    when(
      () => mockSettingsCubit.authChanges,
    ).thenReturn(() => authController.stream);

    when(() => mockProfileCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockProfileCubit.state).thenReturn(
      Profile(nickname: 'test_user', mail: 'test@mail.it', xp: 0.50, level: 1),
    );
    //when(() => mockProfileCubit.authChanges).thenReturn(() => authController.stream);

    when(
      () => mockActivityCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockActivityCubit.state).thenReturn(const <Activity>[]);
    when(
      () => mockActivityCubit.watchDownloadedTrailIds(),
    ).thenAnswer((_) => const Stream.empty());

    when(() => mockNavigationIndexCubit.state).thenReturn(0);
    when(
      () => mockNavigationIndexCubit.stream,
    ).thenAnswer((_) => Stream<int>.value(0));

    when(() => mockMapCubit.state).thenReturn(MapState.initial);
    when(() => mockMapCubit.stream).thenAnswer((_) => const Stream.empty());

    when(
      () => mockFavoriteTrailStore.streamFavoriteTrails(),
    ).thenAnswer((_) => const Stream.empty());

    mockNotificationPermission(true);
  });

  tearDown(() {
    NotificationPermissionHelper.mockIsAndroid = null;
    NotificationPermissionHelper.mockIsIOS = null;
  });

  group('Navigation Widget Tests', () {
    testWidgets('Initial state should render MapPage and NavigationBar items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          child: Navigation(favoriteTrailStore: mockFavoriteTrailStore),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
          navigationIndexCubit: mockNavigationIndexCubit,
          mapCubit: mockMapCubit,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Diary'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      expect(find.byType(MapPage), findsOneWidget);

      await tearDownMap(tester);
    });

    testWidgets('Tapping on Diary tab switches to DiaryPage', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          child: Navigation(favoriteTrailStore: mockFavoriteTrailStore),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
          navigationIndexCubit: NavigationIndexCubit(
            authChanges: () => authController.stream,
          ),
          mapCubit: mockMapCubit,
        ),
      );

      authController.add(FakeUser());

      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Diary'));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryPage), findsOneWidget);
      expect(find.text('Diary'), findsWidgets);

      await tearDownMap(tester);
    });

    testWidgets('Tapping on Profile tab switches to SettingsPage/ProfilePage', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          child: Navigation(favoriteTrailStore: mockFavoriteTrailStore),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
          navigationIndexCubit: NavigationIndexCubit(
            authChanges: () => authController.stream,
          ),
          mapCubit: mockMapCubit,
        ),
      );

      authController.add(FakeUser());
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
          navigationIndexCubit: NavigationIndexCubit(
            authChanges: () => authController.stream,
          ),
        ),
      );

      authController.add(FakeUser());

      expect(find.text('Diary'), findsOneWidget);
      expect(
        find.textContaining(
          'No planned hikes yet.\nSchedule your next adventure!',
        ),
        findsOneWidget,
      );
    });

    testWidgets('SettingsPage renders ProfilePage', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          child: const SettingsPage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
          navigationIndexCubit: NavigationIndexCubit(
            authChanges: () => authController.stream,
          ),
        ),
      );

      authController.add(FakeUser());

      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('Favorites page renders correctly', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: FavoritesPage(favoriteTrailStore: mockFavoriteTrailStore,),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
          navigationIndexCubit: NavigationIndexCubit(
            authChanges: () => authController.stream,
          ),
        ),
      );
      authController.add(FakeUser());

      expect(find.byType(FavoritesPage), findsOneWidget);
    });
  });

  group('Notification Permission Dialog Tests', () {
    testWidgets(
      'Notification permission dialog is shown when permission is denied',
      (WidgetTester tester) async {
        mockNotificationPermission(false);

        await tester.pumpWidget(
          pumpApp(
            child: Navigation(favoriteTrailStore: mockFavoriteTrailStore),
            settingsCubit: mockSettingsCubit,
            profileCubit: mockProfileCubit,
            activityCubit: mockActivityCubit,
            navigationIndexCubit: mockNavigationIndexCubit,
            mapCubit: mockMapCubit,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Notification permission required'), findsOneWidget);
        expect(
          find.textContaining('Without enabling the permission'),
          findsOneWidget,
        );

        await tearDownMap(tester);
      },
    );

    testWidgets(
      'Dialog "Enable notification permission" button is functional',
      (WidgetTester tester) async {
        mockNotificationPermission(false);

        await tester.pumpWidget(
          pumpApp(
            child: Navigation(favoriteTrailStore: mockFavoriteTrailStore),
            settingsCubit: mockSettingsCubit,
            profileCubit: mockProfileCubit,
            activityCubit: mockActivityCubit,
            navigationIndexCubit: mockNavigationIndexCubit,
            mapCubit: mockMapCubit,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Enable notification permission'), findsOneWidget);
        await tester.tap(find.text('Enable notification permission'));
        await tester.pumpAndSettle();

        expect(find.text('Notification permission required'), findsNothing);

        await tearDownMap(tester);
      },
    );

    testWidgets('Dialog "Ignore" button closes the dialog', (
      WidgetTester tester,
    ) async {
      mockNotificationPermission(false);

      await tester.pumpWidget(
        pumpApp(
          child: Navigation(favoriteTrailStore: mockFavoriteTrailStore),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
          navigationIndexCubit: mockNavigationIndexCubit,
          mapCubit: mockMapCubit,
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
