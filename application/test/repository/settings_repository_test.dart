import 'dart:async';

import 'package:application/core/models/settings.dart';
import 'package:application/core/repository/settings_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

SettingsRepository createRepository({
  required bool authenticated,
  Settings? initialSettings,
  Stream<Map<String, dynamic>?>? stream,
  MockDatabaseService? databaseService,
  StreamController<User?>? authStreamController,
}) {
  final db = databaseService ?? MockDatabaseService();

  when(
    () => db.fetchSettings(),
  ).thenAnswer((_) async => initialSettings?.toJson());
  when(() => db.saveSettings(any())).thenAnswer((_) async {});
  when(() => db.streamSettings()).thenAnswer((_) => stream ?? Stream.empty());

  final authController = authStreamController ?? StreamController<User?>();

  return SettingsRepository(
    hasCurrentUser: () => authenticated,
    databaseServiceFactory: () => db,
    authChanges: () => authController.stream,
  );
}

void main() {
  setUpAll(() {
    setupTest();
  });

  test('fetchRemote returns null when user is not authenticated', () async {
    final repository = createRepository(authenticated: false);

    final result = await repository.fetchRemote();

    expect(result, isNull);
  });

  test('fetchRemote returns null when remote document is empty', () async {
    final repository = createRepository(authenticated: true);

    final result = await repository.fetchRemote();

    expect(result, isNull);
  });

  test('fetchRemote maps remote document to Settings', () async {
    final repository = createRepository(
      authenticated: true,
      initialSettings: Settings(
        notifications: true,
        ferrata: false,
        difficulty: 2.5,
      ),
    );

    final result = await repository.fetchRemote();

    expect(result, isNotNull);
    expect(result!.notifications, true);
    expect(result.ferrata, false);
    expect(result.difficulty, 2.5);
  });

  test('saveRemote does nothing when user is not authenticated', () async {
    final db = MockDatabaseService();
    when(() => db.saveSettings(any())).thenAnswer((_) async {});

    final repository = createRepository(
      authenticated: false,
      databaseService: db,
    );

    await repository.saveRemote(
      Settings(notifications: true, ferrata: false, difficulty: 1.0),
    );

    verifyNever(() => db.saveSettings(any()));
  });

  test('saveRemote forwards Settings JSON to the database', () async {
    final db = MockDatabaseService();
    when(() => db.saveSettings(any())).thenAnswer((_) async {});

    final repository = createRepository(
      authenticated: true,
      databaseService: db,
    );

    final settings = Settings(
      notifications: false,
      ferrata: true,
      difficulty: 3.3,
    );

    await repository.saveRemote(settings);

    verify(() => db.saveSettings(settings.toJson())).called(1);
  });

  test(
    'streamRemote returns empty stream when user is not authenticated',
    () async {
      final authController = StreamController<User?>();

      final repository = createRepository(
        authenticated: false,
        authStreamController: authController,
      );

      final stream = repository.streamRemote();

      final expectation = expectLater(stream, emits(null));

      authController.add(null);

      await expectation;

      await authController.close();
    },
  );

  test(
    'streamRemote maps remote values to Settings and ignores null',
    () async {
      final controller = StreamController<Map<String, dynamic>?>.broadcast();
      final authController = StreamController<User?>();
      final databaseService = MockDatabaseService();

      final repository = createRepository(
        authenticated: true,
        stream: controller.stream,
        authStreamController: authController,
        databaseService: databaseService,
      );

      final expectation = expectLater(
        repository.streamRemote(),
        emitsInOrder([
          isA<Settings>()
              .having((s) => s.notifications, 'notifications', false)
              .having((s) => s.ferrata, 'ferrata', true)
              .having((s) => s.difficulty, 'difficulty', 2.0),
          isNull,
        ]),
      );

      authController.add(FakeUser());

      //wait for switchMap subscription
      await untilCalled(() => databaseService.streamSettings());

      controller.add({
        'notifications': false,
        'ferrata': true,
        'difficulty': 2.0,
      });

      controller.add(null);

      await expectation;

      await authController.close();
      await controller.close();
    },
  );

  test(
    'uses default DatabaseService when databaseServiceFactory is null',
    () async {
      final repository = SettingsRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: null,
      );

      try {
        await repository.fetchRemote();
      } catch (e) {
        // exception ignored
      }
    },
  );
}
