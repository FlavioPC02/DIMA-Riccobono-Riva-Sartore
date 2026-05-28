import 'dart:async';

import 'package:application/core/models/activity.dart';
import 'package:application/core/repository/activity_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

void main() {
  setUpAll(() {
    setupTest();
  });

  group('ActivityRepository when no user is signed in', () {
    final repo = ActivityRepository(hasCurrentUser: () => false);

    test('streamActivities returns an empty stream', () async {
      final stream = repo.streamActivities();
      final events = <List<Activity>>[];
      final sub = stream.listen((e) => events.add(e), onError: (_) {});

      await Future<void>.delayed(Duration(milliseconds: 20));
      await sub.cancel();

      expect(events, isEmpty);
    });

    test('addActivity returns null', () async {
      final a = Activity(
        id: '',
        name: 'x',
        status: ActivityStatus.planned,
        date: DateTime.now(),
      );
      final id = await repo.addActivity(a);
      expect(id, isNull);
    });

    test('updateActivity does not throw', () async {
      final a = Activity(
        id: 'i',
        name: 'x',
        status: ActivityStatus.planned,
        date: DateTime.now(),
      );
      await repo.updateActivity(a);
    });

    test('deleteActivity does not throw', () async {
      await repo.deleteActivity('any-id');
    });
  });

  group('ActivityRepository with remote database', () {
    test('streamActivities maps remote data to Activity objects', () async {
      final mockDb = MockDatabaseService();
      final date = DateTime(2026, 1, 1);
      final remoteMap = {
        'id': 'a1',
        'name': 'Walk',
        'status': 'planned',
        'date': Timestamp.fromDate(date),
        'trailName': 'T',
        'distanceKm': 3.0,
        'durationMinutes': 60,
        'xpEarned': 10.0,
        'notes': 'n',
        'difficulty': 'easy',
        'trackedDistance': 0.0,
        'trackedElevationGap': 0.0,
        'trackedTime': 0,
      };

      final controller = StreamController<List<Map<String, dynamic>>>();
      addTearDown(controller.close);

      when(() => mockDb.streamActivities())
          .thenAnswer((_) => controller.stream);

      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
      );

      final results = <List<Activity>>[];
      final sub = repo.streamActivities().listen(results.add);

      controller.add([remoteMap]);
      await Future<void>.delayed(Duration(milliseconds: 20));

      expect(results, hasLength(1));
      expect(results.first.first.id, equals('a1'));

      await sub.cancel();
    });

    test('add/update/delete forward to DatabaseService', () async {
      final mockDb = MockDatabaseService();
      when(() => mockDb.addActivity(any()))
          .thenAnswer((_) async => 'new-id');
      when(() => mockDb.updateActivity(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockDb.deleteActivity(any())).thenAnswer((_) async {});

      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
      );

      final a = Activity(
        id: 'i1',
        name: 'X',
        status: ActivityStatus.planned,
        date: DateTime.now(),
      );

      final id = await repo.addActivity(a);
      expect(id, equals('new-id'));
      verify(() => mockDb.addActivity(a.toJson())).called(1);

      await repo.updateActivity(a);
      verify(() => mockDb.updateActivity(a.id, a.toJson())).called(1);

      await repo.deleteActivity('i1');
      verify(() => mockDb.deleteActivity('i1')).called(1);
    });
  });
}
