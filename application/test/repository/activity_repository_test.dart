import 'dart:async';

import 'package:application/core/models/activity.dart';
import 'package:application/core/models/activity_note.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:application/core/repository/activity_repository.dart';
import 'package:application/services/local_activity_store.dart';
import 'package:application/services/trail_geometry_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

class MockTrailGeometryDataSource extends Mock
    implements TrailGeometryDataSource {}

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

    test(
      'addActivity rejects completed activities without a Firestore user',
      () async {
        final localStore = FakeActivityLocalStore();
        addTearDown(localStore.close);
        final repo = ActivityRepository(
          hasCurrentUser: () => false,
          localStore: localStore,
        );
        final a = Activity(
          id: '',
          name: 'x',
          status: ActivityStatus.completed,
          date: DateTime.now(),
        );

        await expectLater(repo.addActivity(a), throwsA(isA<StateError>()));

        expect(localStore.activities, isEmpty);
      },
    );

    test(
      'updateActivity rejects completed activities without a Firestore user',
      () async {
        final localStore = FakeActivityLocalStore();
        addTearDown(localStore.close);
        final repo = ActivityRepository(
          hasCurrentUser: () => false,
          localStore: localStore,
        );
        final completed = Activity(
          id: 'i',
          name: 'x',
          status: ActivityStatus.completed,
          date: DateTime.now(),
        );

        await expectLater(
          repo.updateActivity(completed),
          throwsA(isA<StateError>()),
        );

        expect(localStore.activities, isEmpty);
      },
    );

    test('deleteActivity does not throw', () async {
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      final repo = ActivityRepository(
        hasCurrentUser: () => false,
        localStore: localStore,
      );
      await repo.deleteActivity('any-id');
    });

    test('fetchActivityDetails retrieves from local when remote is null', () async {
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      final repo = ActivityRepository(
        hasCurrentUser: () => false,
        localStore: localStore,
      );

      final a = Activity(id: 'local_fetch', name: 'Local Only', status: ActivityStatus.planned, date: DateTime.now());
      await localStore.upsertActivity(a);

      final fetched = await repo.fetchActivityDetails('local_fetch');
      expect(fetched?.name, 'Local Only');

      final notFound = await repo.fetchActivityDetails('non_existent');
      expect(notFound, isNull);
    });

    test('saveNote saves only locally if remote is null', () async {
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      final repo = ActivityRepository(
        hasCurrentUser: () => false,
        localStore: localStore,
      );

      final a = Activity(id: 'a1', name: 'Activity Note Test', status: ActivityStatus.planned, date: DateTime.now());
      await localStore.upsertActivity(a);

      final note = ActivityNote(id: 'n1', text: 'Test note', imageUrls: [], createdAt: DateTime.now());
      
      await repo.saveNote(a, note);
      
      final updatedActivity = localStore.activities.firstWhere((element) => element.id == 'a1');
      expect(updatedActivity.notes.length, 1);
      expect(updatedActivity.notes.first.text, 'Test note');
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
        'notes': [],
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

    test(
      'updateActivity caches completed activities after Firestore save',
      () async {
        final mockDb = MockDatabaseService();
        when(
          () => mockDb.updateActivity(any(), any()),
        ).thenAnswer((_) async {});

        final localStore = FakeActivityLocalStore();
        addTearDown(localStore.close);
        final repo = ActivityRepository(
          hasCurrentUser: () => true,
          databaseServiceFactory: () => mockDb,
          localStore: localStore,
        );
        final planned = Activity(
          id: 'i1',
          name: 'X',
          status: ActivityStatus.planned,
          date: DateTime.now(),
        );

        await repo.updateActivity(planned);
        expect(localStore.activities.single.status, ActivityStatus.planned);

        await repo.updateActivity(
          planned.copyWith(status: ActivityStatus.completed),
        );

        expect(localStore.activities.single.status, ActivityStatus.completed);
        verify(() => mockDb.updateActivity('i1', any())).called(2);
      },
    );

    test(
      'completed activity remains visible while the Firestore stream is stale',
      () async {
        final mockDb = MockDatabaseService();
        final remoteController = StreamController<List<Map<String, dynamic>>>();
        addTearDown(remoteController.close);
        when(
          () => mockDb.streamActivities(),
        ).thenAnswer((_) => remoteController.stream);
        when(
          () => mockDb.updateActivity(any(), any()),
        ).thenAnswer((_) async {});

        final localStore = FakeActivityLocalStore();
        addTearDown(localStore.close);
        final planned = Activity(
          id: 'i1',
          name: 'X',
          status: ActivityStatus.planned,
          date: DateTime(2026, 1, 1),
        );
        await localStore.upsertActivity(planned);

        final repo = ActivityRepository(
          hasCurrentUser: () => true,
          databaseServiceFactory: () => mockDb,
          localStore: localStore,
        );
        final emissions = <List<Activity>>[];
        final subscription = repo.streamActivities().listen(emissions.add);
        addTearDown(subscription.cancel);

        remoteController.add([
          {
            'id': 'i1',
            'name': 'X',
            'status': 'planned',
            'date': Timestamp.fromDate(DateTime(2026, 1, 1)),
          },
        ]);
        await Future<void>.delayed(Duration.zero);

        await repo.updateActivity(
          planned.copyWith(status: ActivityStatus.completed),
        );
        await Future<void>.delayed(Duration.zero);

        expect(emissions.last.single.status, ActivityStatus.completed);
      },
    );

    test(
      'updateActivity propagates Firestore failures without a local fallback',
      () async {
        final mockDb = MockDatabaseService();
        when(
          () => mockDb.updateActivity(any(), any()),
        ).thenThrow(Exception('offline'));

        final localStore = FakeActivityLocalStore();
        addTearDown(localStore.close);
        final repo = ActivityRepository(
          hasCurrentUser: () => true,
          databaseServiceFactory: () => mockDb,
          localStore: localStore,
        );
        final completed = Activity(
          id: 'i1',
          name: 'X',
          status: ActivityStatus.completed,
          date: DateTime.now(),
        );

        await expectLater(
          repo.updateActivity(completed),
          throwsA(isA<Exception>()),
        );

        expect(localStore.activities, isEmpty);
      },
    );

    test('fetchActivityDetails from remote success and merges local trailPath', () async {
      final mockDb = MockDatabaseService();
      
      final remoteDoc = {
        'name': 'Remote Hike',
        'status': 'planned',
        'date': Timestamp.now(),
        'trailName': 'Trail Remote',
      };
      
      when(() => mockDb.fetchActivity('sync_id')).thenAnswer((_) async => remoteDoc);
      
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      
      final localActivity = Activity(id: 'sync_id', name: 'Old Name', status: ActivityStatus.planned, date: DateTime.now(), trailPath: [[]]);
      await localStore.upsertActivity(localActivity);

      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
        localStore: localStore,
      );

      final result = await repo.fetchActivityDetails('sync_id');
      
      expect(result?.name, 'Remote Hike');
      expect(result?.trailPath, localActivity.trailPath);
      verify(() => mockDb.fetchActivity('sync_id')).called(1);
    });

    test(
      'fetchActivityDetails downloads and caches a missing trailPath by trailId',
      () async {
        final mockDb = MockDatabaseService();
        final geometrySource = MockTrailGeometryDataSource();
        const downloadedPath = [
          [TrailPoint(lat: 45.1, lng: 9.1), TrailPoint(lat: 45.2, lng: 9.2)],
        ];
        final remoteDoc = {
          'name': 'Remote Hike',
          'status': 'planned',
          'date': Timestamp.now(),
          'trailName': 'Remote Trail',
          'trailId': '12345',
        };

        when(
          () => mockDb.fetchActivity('remote_activity'),
        ).thenAnswer((_) async => remoteDoc);
        when(
          () => geometrySource.fetchTrailPath('12345'),
        ).thenAnswer((_) async => downloadedPath);

        final localStore = FakeActivityLocalStore();
        addTearDown(localStore.close);
        final repo = ActivityRepository(
          hasCurrentUser: () => true,
          databaseServiceFactory: () => mockDb,
          localStore: localStore,
          trailGeometrySource: geometrySource,
        );

        final result = await repo.fetchActivityDetails('remote_activity');

        expect(result?.trailPath, downloadedPath);
        expect(localStore.activities.single.trailPath, downloadedPath);
        verify(() => geometrySource.fetchTrailPath('12345')).called(1);
      },
    );

    test(
      'fetchActivityDetails reuses the local trailPath without downloading it',
      () async {
        final mockDb = MockDatabaseService();
        final geometrySource = MockTrailGeometryDataSource();
        const cachedPath = [
          [TrailPoint(lat: 45.1, lng: 9.1)],
        ];
        final remoteDoc = {
          'name': 'Remote Hike',
          'status': 'planned',
          'date': Timestamp.now(),
          'trailId': '12345',
        };

        when(
          () => mockDb.fetchActivity('cached_activity'),
        ).thenAnswer((_) async => remoteDoc);

        final localStore = FakeActivityLocalStore();
        addTearDown(localStore.close);
        await localStore.upsertActivity(
          Activity(
            id: 'cached_activity',
            name: 'Cached',
            status: ActivityStatus.planned,
            date: DateTime.now(),
            trailId: '12345',
            trailPath: cachedPath,
          ),
        );
        final repo = ActivityRepository(
          hasCurrentUser: () => true,
          databaseServiceFactory: () => mockDb,
          localStore: localStore,
          trailGeometrySource: geometrySource,
        );

        final result = await repo.fetchActivityDetails('cached_activity');

        expect(result?.trailPath, cachedPath);
        verifyNever(() => geometrySource.fetchTrailPath(any()));
      },
    );

    test(
      'fetchActivityDetails keeps remote metadata when trail download fails',
      () async {
        final mockDb = MockDatabaseService();
        final geometrySource = MockTrailGeometryDataSource();
        final remoteDoc = {
          'name': 'Remote Hike',
          'status': 'planned',
          'date': Timestamp.now(),
          'trailId': '12345',
        };

        when(
          () => mockDb.fetchActivity('offline_activity'),
        ).thenAnswer((_) async => remoteDoc);
        when(
          () => geometrySource.fetchTrailPath('12345'),
        ).thenThrow(Exception('offline'));

        final localStore = FakeActivityLocalStore();
        addTearDown(localStore.close);
        final repo = ActivityRepository(
          hasCurrentUser: () => true,
          databaseServiceFactory: () => mockDb,
          localStore: localStore,
          trailGeometrySource: geometrySource,
        );

        final result = await repo.fetchActivityDetails('offline_activity');

        expect(result?.name, 'Remote Hike');
        expect(result?.trailPath, isEmpty);
        expect(localStore.activities.single.name, 'Remote Hike');
      },
    );

    test('fetchActivityDetails fallbacks to local store if remote fetch fails', () async {
      final mockDb = MockDatabaseService();
      when(() => mockDb.fetchActivity('err_id')).thenThrow(Exception('Network Error'));
      
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      
      final fallbackActivity = Activity(id: 'err_id', name: 'Fallback Hike', status: ActivityStatus.planned, date: DateTime.now());
      await localStore.upsertActivity(fallbackActivity);

      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
        localStore: localStore,
      );

      final result = await repo.fetchActivityDetails('err_id');
      
      expect(result?.name, 'Fallback Hike');
      verify(() => mockDb.fetchActivity('err_id')).called(1);
    });

    test('saveNote adds new note to remote array', () async {
      final mockDb = MockDatabaseService();
      when(() => mockDb.addNoteToArray(any(), any())).thenAnswer((_) async {});
      
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      
      final a = Activity(id: 'a2', name: 'Note Test', status: ActivityStatus.planned, date: DateTime.now());
      await localStore.upsertActivity(a);

      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
        localStore: localStore,
      );

      final newNote = ActivityNote(id: 'n2', text: 'Fresh Note', imageUrls: [], createdAt: DateTime.now());
      await repo.saveNote(a, newNote);

      verify(() => mockDb.addNoteToArray('a2', any())).called(1);
      verifyNever(() => mockDb.removeNoteFromArray(any(), any()));
      
      expect(localStore.activities.firstWhere((act) => act.id == 'a2').notes.length, 1);
    });

    test('saveNote updates existing note by removing old and adding new to remote array', () async {
      final mockDb = MockDatabaseService();
      when(() => mockDb.addNoteToArray(any(), any())).thenAnswer((_) async {});
      when(() => mockDb.removeNoteFromArray(any(), any())).thenAnswer((_) async {});
      
      final oldNote = ActivityNote(id: 'n3', text: 'Old Text', imageUrls: [], createdAt: DateTime.now());
      final a = Activity(id: 'a3', name: 'Update Note Test', status: ActivityStatus.planned, date: DateTime.now(), notes: [oldNote]);
      
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      await localStore.upsertActivity(a);

      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
        localStore: localStore,
      );

      final updatedNote = ActivityNote(id: 'n3', text: 'New Text', imageUrls: [], createdAt: oldNote.createdAt);
      await repo.saveNote(a, updatedNote);

      verify(() => mockDb.removeNoteFromArray('a3', oldNote.toJson())).called(1);
      verify(() => mockDb.addNoteToArray('a3', updatedNote.toJson())).called(1);
      
      expect(localStore.activities.firstWhere((act) => act.id == 'a3').notes.length, 1);
      expect(localStore.activities.firstWhere((act) => act.id == 'a3').notes.first.text, 'New Text');
    });

    test('deleteNote removes from local store and remote array', () async {
      final mockDb = MockDatabaseService();
      when(() => mockDb.removeNoteFromArray(any(), any())).thenAnswer((_) async {});
      
      final noteToDelete = ActivityNote(id: 'del_1', text: 'To Delete', imageUrls: [], createdAt: DateTime.now());
      final a = Activity(id: 'a4', name: 'Delete Note Test', status: ActivityStatus.planned, date: DateTime.now(), notes: [noteToDelete]);
      
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      await localStore.upsertActivity(a);

      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
        localStore: localStore,
      );

      await repo.deleteNote(a, noteToDelete);

      verify(() => mockDb.removeNoteFromArray('a4', noteToDelete.toJson())).called(1);
      expect(localStore.activities.firstWhere((act) => act.id == 'a4').notes.isEmpty, true);
    });

    test('streamActivities does not sync locally completed activities', () async {
      final mockDb = MockDatabaseService();
      final controller = StreamController<List<Map<String, dynamic>>>();
      addTearDown(controller.close);

      when(() => mockDb.streamActivities()).thenAnswer((_) => controller.stream);
      when(() => mockDb.updateActivity(any(), any())).thenAnswer((_) async {});
      
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);
      
      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
        localStore: localStore,
      );

      final results = <List<Activity>>[];
      final sub = repo.streamActivities().listen(results.add);
      
      final pendingCompleted = Activity(id: 'sync_me', name: 'Local Done', status: ActivityStatus.completed, date: DateTime.now());
      await localStore.upsertActivity(pendingCompleted);
      
      await Future<void>.delayed(Duration(milliseconds: 50));

      verifyNever(() => mockDb.updateActivity(any(), any()));
      
      await sub.cancel();
    });

    test('merged streams are correctly deduped and sorted by date descending', () async {
      final mockDb = MockDatabaseService();
      final remoteController = StreamController<List<Map<String, dynamic>>>();
      addTearDown(remoteController.close);

      when(() => mockDb.streamActivities()).thenAnswer((_) => remoteController.stream);
      
      final localStore = FakeActivityLocalStore();
      addTearDown(localStore.close);

      final repo = ActivityRepository(
        hasCurrentUser: () => true,
        databaseServiceFactory: () => mockDb,
        localStore: localStore,
      );

      final results = <List<Activity>>[];
      final sub = repo.streamActivities().listen(results.add);

      final olderDate = DateTime(2026, 1, 1);
      final newerDate = DateTime(2026, 1, 5);

      await localStore.upsertActivity(Activity(id: 'local1', name: 'Older Local', status: ActivityStatus.planned, date: olderDate));
      
      remoteController.add([
        {
          'id': 'local1',
          'name': 'Updated from Remote',
          'status': 'planned',
          'date': Timestamp.fromDate(olderDate),
        },
        {
          'id': 'remote1',
          'name': 'Newer Remote',
          'status': 'completed',
          'date': Timestamp.fromDate(newerDate),
        }
      ]);

      await Future<void>.delayed(Duration(milliseconds: 50));

      final latestEmission = results.last;
      
      expect(latestEmission.length, 2);
      expect(latestEmission[0].id, 'remote1');
      expect(latestEmission[1].id, 'local1');
      expect(latestEmission[1].name, 'Older Local');
      
      await sub.cancel();
    });
  });
}
