import 'package:application/core/models/profile.dart';
import 'package:application/core/models/settings.dart';
import 'package:application/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../mocks/mocks.mocks.dart';
import '../utils/pump_app.dart';
import '../utils/test_config.dart';

void main() {
  setupTest();

  group(
    'Testing UI and interactions', 
    () {
      testWidgets(
        'Profile page loads and interacts', 
        (tester) async {
          final mockSettingsCubit = MockSettingsCubit();
          final mockProfileCubit = MockProfileCubit();

          when(mockSettingsCubit.state).thenReturn(
            Settings(
              notifications: true,
              ferrata: true,
              difficulty: 0.5,
            ),
          );

          when(mockProfileCubit.state).thenReturn(
            Profile(
              nickname: 'test', 
              mail: 'test@mail.it', 
              xp: 0.66,
            ),
          );

          when(mockSettingsCubit.stream).thenAnswer((_) => const Stream.empty());
          when(mockProfileCubit.stream).thenAnswer((_) => const Stream.empty());

          await tester.pumpWidget(
            pumpApp(
              child: const ProfilePage(),
              settingsCubit: mockSettingsCubit,
              profileCubit: mockProfileCubit,
            ),
          );

          expect(find.text('Profile'), findsOneWidget);

          await tester.tap(find.byType(SwitchListTile).first);
          await tester.pump();

          verify(mockSettingsCubit.updateFerrata(any)).called(1);
      });

      testWidgets(
        'Slider test', 
        (tester) async {
          final mockSettingsCubit = MockSettingsCubit();
          final mockProfileCubit = MockProfileCubit();

          when(mockSettingsCubit.state).thenReturn(
            Settings(
              notifications: true,
              ferrata: true,
              difficulty: 1, // Starting at intermediate difficulty
            ),
          );

          when(mockProfileCubit.state).thenReturn(
            Profile(
              nickname: 'test', 
              mail: 'test@mail.it', 
              xp: 0.66,
            ),
          );

          when(mockSettingsCubit.stream).thenAnswer((_) => const Stream.empty());
          when(mockProfileCubit.stream).thenAnswer((_) => const Stream.empty());

          await tester.pumpWidget(
            pumpApp(
              child: const ProfilePage(),
              settingsCubit: mockSettingsCubit,
              profileCubit: mockProfileCubit,
            ),
          );

          final sliderFinder = find.byType(Slider);

          await tester.drag(sliderFinder, const Offset(100, 0)); // Dragging slider to the right => expert difficulty
          await tester.pump();

          verify(mockSettingsCubit.updateDifficulty(2)).called(1);
        }
      );
    }
  );
}