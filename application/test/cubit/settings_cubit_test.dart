import 'dart:async';

import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/settings.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

MockSettingsRepository createMockRepo({
  Settings? initialSettings,
  Stream<Settings?>? remoteStream,
}) {
  final repo = MockSettingsRepository();

  when(() => repo.fetchRemote()).thenAnswer((_) async => initialSettings);
  when(
    () => repo.streamRemote(),
  ).thenAnswer((_) => remoteStream ?? Stream.empty());
  when(() => repo.saveRemote(any())).thenAnswer((_) async {});

  return repo;
}

void main() {
  late StreamController<User?> authController;

  setUpAll(() {
    setupTest();
  });

  setUp(() {
    authController = StreamController<User?>();
  });

  blocTest<SettingsCubit, Settings>(
    'update notifications test',
    build: () => SettingsCubit(
      createMockRepo(),
      authChanges: () => authController.stream,
    ),
    act: (cubit) => cubit.updateNotifications(false),
    expect: () => [
      isA<Settings>().having((s) => s.notifications, 'notifications', false),
    ],
  );

  blocTest<SettingsCubit, Settings>(
    'update ferrata test',
    build: () => SettingsCubit(
      createMockRepo(),
      authChanges: () => authController.stream,
    ),
    act: (cubit) => cubit.updateFerrata(true),
    expect: () => [isA<Settings>().having((s) => s.ferrata, 'ferrata', true)],
  );

  blocTest<SettingsCubit, Settings>(
    'update difficulty test',
    build: () => SettingsCubit(
      createMockRepo(),
      authChanges: () => authController.stream,
    ),
    act: (cubit) => cubit.updateDifficulty(0.0),
    expect: () => [
      isA<Settings>().having((s) => s.difficulty, 'difficulty', 0.0),
    ],
  );

  blocTest<SettingsCubit, Settings>(
    'bootstrap emits initial remote settings when available',
    build: () {
      final sc = SettingsCubit(
        createMockRepo(
          initialSettings: Settings(
            notifications: false,
            ferrata: true,
            difficulty: 1.0,
          ),
        ),
        authChanges: () => authController.stream,
      );
      authController.add(FakeUser());
      return sc;
    },
    expect: () => [
      isA<Settings>()
          .having((s) => s.notifications, 'notifications', false)
          .having((s) => s.ferrata, 'ferrata', true)
          .having((s) => s.difficulty, 'difficulty', 1.0),
    ],
  );

  blocTest<SettingsCubit, Settings>(
    'bootstrap does not emit when fetchRemote returns null',
    build: () => SettingsCubit(
      createMockRepo(initialSettings: null),
      authChanges: () => authController.stream,
    ),
    expect: () => <Matcher>[],
  );

  test('stream remote emits new value and ignores null', () async {
    final controller = StreamController<Settings?>();
    final cubit = SettingsCubit(
      createMockRepo(remoteStream: controller.stream),
      authChanges: () => authController.stream,
    );

    final emitted = <Settings>[];
    final sub = cubit.stream.listen(emitted.add);

    authController.add(FakeUser());

    await Future<void>.delayed(Duration.zero);
    controller.add(
      Settings(notifications: false, ferrata: true, difficulty: 2.0),
    );
    controller.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(emitted.length, 1);
    expect(emitted.first.notifications, false);
    expect(emitted.first.ferrata, true);
    expect(emitted.first.difficulty, 2.0);

    await sub.cancel();
    await cubit.close();
    await controller.close();
  });

  test('close cancels remote subscription', () async {
    final controller = StreamController<Settings?>();
    final cubit = SettingsCubit(
      createMockRepo(remoteStream: controller.stream),
      authChanges: () => authController.stream,
    );

    authController.add(FakeUser());

    await Future<void>.delayed(Duration.zero);
    expect(controller.hasListener, true);

    await cubit.close();
    expect(controller.hasListener, false);

    await controller.close();
  });

  test('update methods persist via saveRemote', () async {
    final repo = createMockRepo();
    final cubit = SettingsCubit(repo, authChanges: () => authController.stream);

    cubit.updateNotifications(false);
    cubit.updateFerrata(true);
    cubit.updateDifficulty(0.3);

    await Future<void>.delayed(Duration.zero);
    verify(() => repo.saveRemote(any())).called(greaterThanOrEqualTo(3));

    await cubit.close();
  });

  test('toJson and fromJson convert settings correctly', () async {
    final cubit = SettingsCubit(
      createMockRepo(),
      authChanges: () => authController.stream,
    );
    const map = {'notifications': false, 'ferrata': true, 'difficulty': 0.7};

    final parsed = cubit.fromJson(map);
    expect(parsed, isNotNull);
    expect(parsed!.notifications, false);
    expect(parsed.ferrata, true);
    expect(parsed.difficulty, 0.7);
    expect(cubit.toJson(parsed), map);

    await cubit.close();
  });
}
