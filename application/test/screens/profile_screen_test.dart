import 'package:application/core/models/activity.dart';
import 'package:application/core/models/profile.dart';
import 'package:application/core/models/settings.dart';
import 'package:application/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/pump_app.dart';
import '../utils/test_config.dart';

void main() {
  late MockSettingsCubit mockSettingsCubit;
  late MockProfileCubit mockProfileCubit;
  late MockActivityCubit mockActivityCubit;

  setUpAll(() {
    setupTest();
  });

  setUp(() {
    mockSettingsCubit = MockSettingsCubit();
    mockProfileCubit = MockProfileCubit();
    mockActivityCubit = MockActivityCubit();

    when(
      () => mockSettingsCubit.state,
    ).thenReturn(Settings(notifications: true, ferrata: true, difficulty: 1));
    when(
      () => mockSettingsCubit.stream,
    ).thenAnswer((_) => const Stream.empty());

    when(() => mockProfileCubit.state).thenReturn(
      Profile(nickname: 'test', mail: 'test@mail.it', xp: 150, level: 3),
    );
    when(() => mockProfileCubit.stream).thenAnswer((_) => const Stream.empty());

    when(() => mockActivityCubit.state).thenReturn(List<Activity>.empty());
    when(
      () => mockActivityCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
  });

  group('Testing UI and interactions', () {
    testWidgets('Profile page loads and interacts', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );

      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pump();

      verify(() => mockSettingsCubit.updateFerrata(any())).called(1);
    });

    testWidgets('Slider test', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );

      final sliderFinder = find.byType(Slider);

      await tester.drag(
        sliderFinder,
        const Offset(100, 0),
      ); // Dragging slider to the right => expert difficulty
      await tester.pump();

      verify(() => mockSettingsCubit.updateDifficulty(2)).called(1);
    });
  });

  group('Switch test', () {
    testWidgets('Ferrata switch test', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );

      final ferrataSwitchFinder = find.byIcon(Icons.hiking);

      // Set ferrata to false
      await tester.tap(ferrataSwitchFinder);
      await tester.pump();

      verify(() => mockSettingsCubit.updateFerrata(false)).called(1);
    });

    testWidgets('Notification switch test', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );

      final notificationSwitchFinder = find.byIcon(Icons.notifications);

      await tester.ensureVisible(notificationSwitchFinder);
      await tester.tap(notificationSwitchFinder);
      await tester.pump();

      verify(() => mockSettingsCubit.updateNotifications(false)).called(1);
    });
  });

  group('Change nickname tests', () {
    testWidgets('Change nickname form appears after tapping', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );

      final changeNicknameListTileFinder = find.ancestor(
        of: find.text('Change nickname'),
        matching: find.byType(ListTile),
      );
      final crossFadeFinder = find.byType(
        AnimatedCrossFade,
      ); // Component which manages the visibility of the form
      final expandMoreIconFinder = find.widgetWithIcon(
        ListTile,
        Icons.expand_more,
      );
      final expandLessIconFinder = find.widgetWithIcon(
        ListTile,
        Icons.expand_less,
      );

      expect(changeNicknameListTileFinder, findsOneWidget);
      expect(crossFadeFinder, findsOneWidget);

      // t0: form hidden and icon = expand_more
      expect(
        tester.widget<AnimatedCrossFade>(crossFadeFinder).crossFadeState,
        CrossFadeState.showFirst,
      );
      expect(expandLessIconFinder, findsNothing);
      expect(expandMoreIconFinder, findsOneWidget);

      // t1: form shown and icon = expand_less
      await tester.ensureVisible(changeNicknameListTileFinder);
      await tester.pumpAndSettle();
      await tester.tap(changeNicknameListTileFinder);
      await tester.pumpAndSettle();

      expect(
        tester.widget<AnimatedCrossFade>(crossFadeFinder).crossFadeState,
        CrossFadeState.showSecond,
      );
      expect(expandMoreIconFinder, findsNothing);
      expect(expandLessIconFinder, findsOneWidget);

      // t2: form hidden again after second tap
      await tester.tap(changeNicknameListTileFinder);
      await tester.pumpAndSettle();

      expect(
        tester.widget<AnimatedCrossFade>(crossFadeFinder).crossFadeState,
        CrossFadeState.showFirst,
      );
      expect(expandLessIconFinder, findsNothing);
      expect(expandMoreIconFinder, findsOneWidget);
    });

    testWidgets('Change nickname test', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );

      final changeNicknameListTileFinder = find.ancestor(
        of: find.text('Change nickname'),
        matching: find.byType(ListTile),
      );
      final changeNicknameTextFieldFinder = find.byType(TextField);
      final saveNicknameButtonFinder = find.byType(ElevatedButton);

      // tap the ListTile to show the form
      await tester.ensureVisible(changeNicknameListTileFinder);
      await tester.tap(changeNicknameListTileFinder);
      await tester.pump();

      // Insert new nickname
      await tester.enterText(changeNicknameTextFieldFinder, 'newNickname');

      await tester.ensureVisible(saveNicknameButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveNicknameButtonFinder);
      await tester.pump();

      verify(() => mockProfileCubit.updateNickname('newNickname')).called(1);
    });
  });

  group('XP test', () {
    testWidgets('XP header shows correc level text', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          activityCubit: mockActivityCubit,
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
        ),
      );

      expect(find.text('Level 3'), findsOneWidget);
    });

    testWidgets('XP bar progress uses xpLength value', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          activityCubit: mockActivityCubit,
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

      expect(
        indicator.value,
        mockProfileCubit.state.xp /
            totalXpTillNextLevel(mockProfileCubit.state.level),
      );
    });

    testWidgets('XP progress does not exceed 1.0', (tester) async {
      when(() => mockProfileCubit.state).thenReturn(
        Profile(
          nickname: 'test',
          mail: 'test@mail.test',
          xp: 15000.0,
          level: 3,
        ),
      );
      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

      expect(indicator.value, greaterThanOrEqualTo(0));
      expect(indicator.value, lessThanOrEqualTo(1));
    });

    testWidgets('XP header works for level 0', (tester) async {
      when(() => mockProfileCubit.state).thenReturn(
        Profile(
          nickname: 'test',
          mail: 'test@mail.test',
          xp: 24,
          level: 0,
        ),
      );

      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );

      expect(find.text('Level 0'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

      expect(indicator.value, 0.2);
    });
  });

  group('Logout test', () {
    testWidgets('Exit button test', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const ProfilePage(),
          settingsCubit: mockSettingsCubit,
          profileCubit: mockProfileCubit,
          activityCubit: mockActivityCubit,
        ),
      );

      final exitListTileFinder = find.byIcon(Icons.power_settings_new);

      await tester.ensureVisible(exitListTileFinder);
      await tester.pump();
      await tester.tap(exitListTileFinder);
      await tester.pumpAndSettle();

      expect(find.text('Logout failed. Try again.'), findsOneWidget);
    });
  });
}
