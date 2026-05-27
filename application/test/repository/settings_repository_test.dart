import 'dart:async';

import 'package:application/core/models/settings.dart';
import 'package:application/core/repository/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

SettingsRepository createRepository({
  required bool authenticated,
  Settings? initialSettings,
  Stream<Map<String, dynamic>?>? stream,
  MockDatabaseService? databaseService,
}) {
  final db = databaseService ?? MockDatabaseService();

  when(() => db.fetchSettings())
      .thenAnswer((_) async => initialSettings?.toJson());
  when(() => db.saveSettings(any())).thenAnswer((_) async {});
  when(() => db.streamSettings()).thenAnswer((_) => stream ?? Stream.empty());

  return SettingsRepository(
    hasCurrentUser: () => authenticated,
    databaseServiceFactory: () => db,
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
      initialSettings: Settings(notifications: true, ferrata: false, difficulty: 2.5),
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

    final repository = createRepository(authenticated: false, databaseService: db);

    await repository.saveRemote(Settings(notifications: true, ferrata: false, difficulty: 1.0));

    verifyNever(() => db.saveSettings(any()));
  });

  test('saveRemote forwards Settings JSON to the database', () async {
    final db = MockDatabaseService();
    when(() => db.saveSettings(any())).thenAnswer((_) async {});

    final repository = createRepository(authenticated: true, databaseService: db);

    final settings = Settings(notifications: false, ferrata: true, difficulty: 3.3);

    await repository.saveRemote(settings);

    verify(() => db.saveSettings(settings.toJson())).called(1);
  });

  test('streamRemote returns empty stream when user is not authenticated', () async {
    final repository = createRepository(authenticated: false);

    expect(repository.streamRemote(), emitsDone);
  });

  test('streamRemote maps remote values to Settings and ignores null', () async {
    final controller = StreamController<Map<String, dynamic>?>();
    final repository = createRepository(
      authenticated: true,
      stream: controller.stream,
    );

    final emitted = <Settings?>[];
    final sub = repository.streamRemote().listen(emitted.add);

    controller.add({'notifications': false, 'ferrata': true, 'difficulty': 4.0});
    controller.add(null);
    await controller.close();
    await Future<void>.delayed(Duration.zero);

    expect(emitted, hasLength(2));
    expect(emitted.first, isA<Settings>());
    expect(emitted.first!.notifications, false);
    expect(emitted.first!.ferrata, true);
    expect(emitted.first!.difficulty, 4.0);
    expect(emitted.last, isNull);

    await sub.cancel();
  });
}
