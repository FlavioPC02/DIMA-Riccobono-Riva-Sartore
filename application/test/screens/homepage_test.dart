import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:application/core/models/settings.dart';
import 'package:application/core/models/profile.dart';
import '../utils/pump_app.dart';

import 'package:application/screens/homepage.dart';
import 'package:application/screens/profile_screen.dart';
import 'package:application/screens/map_page.dart';
import '../mocks/mocks.mocks.dart'; 

import '../utils/map_test_helper.dart';

void main() {
  late MockSettingsCubit mockSettingsCubit;
  late MockProfileCubit mockProfileCubit;

  setUpAll(() async {
    dotenv.testLoad(fileInput: '''MAPBOX_ACCESS_TOKEN=test_token_123''');
    HttpOverrides.global = FakeHttpOverrides();
  });

  setUp(() {
    GeolocatorPlatform.instance = MockGeolocatorPlatform();

    mockSettingsCubit = MockSettingsCubit();
    mockProfileCubit = MockProfileCubit();

    when(mockSettingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(mockSettingsCubit.state).thenReturn(
      Settings(
        notifications: true,
        ferrata: true,
        difficulty: 0.5,
      ),
    );

    when(mockProfileCubit.stream).thenAnswer((_) => const Stream.empty());
    when(mockProfileCubit.state).thenReturn(
      Profile(
        nickname: 'test_user', 
        mail: 'test@mail.it', 
        xp: 0.50,
      ),
    );
  });

  group('Navigation Widget Tests', () {
    
    testWidgets('Initial state should render MapPage and NavigationBar items', (WidgetTester tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const Navigation(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
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
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Diary'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('diary'), findsWidgets); 
      
      await tearDownMap(tester);
    });

    testWidgets('Tapping on Profile tab switches to SettingsPage/ProfilePage', (WidgetTester tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const Navigation(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
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
        ),
      );
      
      expect(find.text('diary'), findsOneWidget);
    });

    testWidgets('SettingsPage renders ProfilePage', (WidgetTester tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const SettingsPage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
        ),
      );
      
      expect(find.byType(ProfilePage), findsOneWidget);
    });
  });
}