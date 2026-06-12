import 'dart:async';

import 'package:application/core/models/activity.dart';
import 'package:application/core/repository/activity_repository.dart';
import 'package:application/services/local_activity_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

class FakeActivityLocalStore implements ActivityLocalDataSource {
  final _controller = StreamController<List<Activity>>.broadcast();
  final List<Activity> _activities = [];
  int _nextId = 0;

  @override
  String createId() {
    _nextId += 1;
    return 'local_$_nextId';
  }

  @override
  Stream<List<Activity>> streamActivities() async* {
    yield List<Activity>.from(_activities);
    yield* _controller.stream;
  }

  @override
  Future<String> upsertActivity(Activity activity) async {
    final id = activity.id.isEmpty ? createId() : activity.id;
    final saved = activity.copyWith(id: id);
    _activities.removeWhere((a) => a.id == id);
    _activities.add(saved);
    _emit();
    return id;
  }

  @override
  Future<void> deleteActivity(String id) async {
    _activities.removeWhere((a) => a.id == id);
    _emit();
  }

  List<Activity> get activities => List<Activity>.from(_activities);

  Future<void> close() => _controller.close();

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List<Activity>.from(_activities));
    }
  }
}

void main() {
  setUpAll(() {
    setupTest();
  });

  group('ActivityRepository when no user is signed in', () {
    test('streamActivities returns an empty stream', () async {
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      final repo = ActivityRepository(
        hasCurrentUser: () => false,
        localStore: localStore,
      );

      final stream = repo.streamActivities();
      final events = <List<Activity>>[];
      final sub = stream.listen((e) => events.add(e), onError: (_) {});

      await Future<void>.delayed(Duration(milliseconds: 20));
      await sub.cancel();

      expect(events, hasLength(1));
      expect(events.first, isEmpty);
    });

    test('addActivity saves locally and returns a local id', () async {
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      final repo = ActivityRepository(
        hasCurrentUser: () => false,
        localStore: localStore,
      );
      final a = Activity(
        id: '',
        name: 'x',
        status: ActivityStatus.planned,
        date: DateTime.now(),
      );
      final id = await repo.addActivity(a);
      expect(id, equals('local_1'));
      expect(localStore.activities.single.id, equals('local_1'));
    });

    test('updateActivity does not throw', () async {
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      final repo = ActivityRepository(
        hasCurrentUser: () => false,
        localStore: localStore,
      );
      final a = Activity(
        id: 'i',
        name: 'x',
        status: ActivityStatus.planned,
        date: DateTime.now(),
      );
      await repo.updateActivity(a);
    });

    test('deleteActivity does not throw', () async {
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      final repo = ActivityRepository(
        hasCurrentUser: () => false,
        localStore: localStore,
      );
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

      when(
        () => mockDb.streamActivities(),
      ).thenAnswer((_) => controller.stream);

      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
        localStore: localStore,
      );

      final results = <List<Activity>>[];
      final sub = repo.streamActivities().listen(results.add);

      controller.add([remoteMap]);
      await Future<void>.delayed(Duration(milliseconds: 20));

      expect(results.last.first.id, equals('a1'));

      await sub.cancel();
    });

    test('add/update/delete forward to DatabaseService', () async {
      final mockDb = MockDatabaseService();
      when(() => mockDb.updateActivity(any(), any())).thenAnswer((_) async {});
      when(() => mockDb.deleteActivity(any())).thenAnswer((_) async {});

      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
        localStore: localStore,
      );

      final a = Activity(
        id: 'i1',
        name: 'X',
        status: ActivityStatus.planned,
        date: DateTime.now(),
      );

      final id = await repo.addActivity(a);
      expect(id, equals('i1'));
      verify(() => mockDb.updateActivity(a.id, a.toJson())).called(1);

      await repo.updateActivity(a);
      verify(() => mockDb.updateActivity(a.id, a.toJson())).called(1);

      await repo.deleteActivity('i1');
      verify(() => mockDb.deleteActivity('i1')).called(1);
    });
  });
}
