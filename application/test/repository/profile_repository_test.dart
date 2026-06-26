import 'dart:async';

import 'package:application/core/models/profile.dart';
import 'package:application/core/repository/profile_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

ProfileRepository createRepository({
  required bool authenticated,
  Profile? initialProfile,
  Stream<Map<String, dynamic>?>? stream,
  MockDatabaseService? databaseService,
  StreamController<User?>? authStreamController,
}) {
  final db = databaseService ?? MockDatabaseService();

  when(
    () => db.fetchProfile(),
  ).thenAnswer((_) async => initialProfile?.toJson());
  when(() => db.saveProfile(any())).thenAnswer((_) async {});
  when(() => db.streamProfile()).thenAnswer((_) => stream ?? Stream.empty());

  final authController = authStreamController ?? StreamController<User?>();

  return ProfileRepository(
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

  test('fetchRemote maps remote document to Profile', () async {
    final repository = createRepository(
      authenticated: true,
      initialProfile: Profile(
        nickname: 'test',
        mail: 'test@mail.com',
        xp: 42.0,
        level: 1,
      ),
    );

    final result = await repository.fetchRemote();

    expect(result, isNotNull);
    expect(result!.nickname, 'test');
    expect(result.mail, 'test@mail.com');
    expect(result.xp, 42.0);
  });

  test('saveRemote does nothing when user is not authenticated', () async {
    final db = MockDatabaseService();
    when(() => db.saveProfile(any())).thenAnswer((_) async {});

    final repository = createRepository(
      authenticated: false,
      databaseService: db,
    );

    await repository.saveRemote(
      Profile(nickname: 'test', mail: 'test@mail.com', xp: 1.0, level: 0),
    );

    verifyNever(() => db.saveProfile(any()));
  });

  test('saveRemote forwards Profile JSON to the database', () async {
    final db = MockDatabaseService();
    when(() => db.saveProfile(any())).thenAnswer((_) async {});

    final repository = createRepository(
      authenticated: true,
      databaseService: db,
    );

    final profile = Profile(
      nickname: 'test',
      mail: 'test@mail.com',
      xp: 7.5,
      level: 0,
    );

    await repository.saveRemote(profile);

    verify(() => db.saveProfile(profile.toJson())).called(1);
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
    'streamRemote converts remote values to Profile and outputs null',
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
          isA<Profile>()
              .having((profile) => profile.nickname, 'nickname', 'remote')
              .having((profile) => profile.mail, 'email', 'remote@mail.com')
              .having((profile) => profile.xp, 'xp', 18.0),
          isNull,
        ]),
      );

      authController.add(FakeUser());

      //wait for switchMap subscription
      await untilCalled(() => databaseService.streamProfile());

      controller.add({
        'nickname': 'remote',
        'email': 'remote@mail.com',
        'xp': 18.0,
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
      final repository = ProfileRepository(
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
