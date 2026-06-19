import 'dart:async';

import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:application/core/models/activity_note.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

class FakeActivity extends Fake implements Activity {}
class FakeActivityNote extends Fake implements ActivityNote {}

MockActivityRepository createMockRepo({
  Stream<List<Activity>>? remoteStream,
}) {
  final repo = MockActivityRepository();

  when(() => repo.streamActivities()).thenAnswer(
    (_) => remoteStream ?? Stream<List<Activity>>.empty(),
  );
  when(() => repo.addActivity(any())).thenAnswer((_) async => 'new-id');
  when(() => repo.updateActivity(any())).thenAnswer((_) async {});
  when(() => repo.deleteActivity(any())).thenAnswer((_) async {});

  when(() => repo.fetchActivityDetails(any())).thenAnswer((_) async => null);
  when(() => repo.saveNote(any(), any())).thenAnswer((_) async {});
  when(() => repo.deleteNote(any(), any())).thenAnswer((_) async {});

  return repo;
}

Activity buildActivity({
  String id = '',
  String name = 'Morning hike',
  ActivityStatus status = ActivityStatus.planned,
  DateTime? date,
  String trailName = 'Trail',
  double distanceKm = 7.5,
  int durationMinutes = 90,
  double xpEarned = 120,
  List<ActivityNote>? notes,
  ActivityDifficulty difficulty = ActivityDifficulty.moderate,
  double trackedDistance = 0,
  double trackedElevationGap = 0,
  Duration trackedTime = Duration.zero,
}) {
  return Activity(
    id: id,
    name: name,
    status: status,
    date: date ?? DateTime(2026, 1, 1),
    trailName: trailName,
    distanceKm: distanceKm,
    durationMinutes: durationMinutes,
    xpEarned: xpEarned,
    notes: notes ?? const [],
    difficulty: difficulty,
    trackedDistance: trackedDistance,
    trackedElevationGap: trackedElevationGap,
    trackedTime: trackedTime,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeActivity());
    registerFallbackValue(FakeActivityNote());
    setupTest();
  });

  group('ActivityCubit Initialization & Stream', () {
    test('starts with an empty activity list', () {
      final cubit = ActivityCubit(createMockRepo());
      expect(cubit.state, isEmpty);
    });

    blocTest<ActivityCubit, List<Activity>>(
      'emits activities coming from the repository stream',
      build: () {
        final controller = StreamController<List<Activity>>();
        addTearDown(controller.close);
        final repo = createMockRepo(remoteStream: controller.stream);
        return ActivityCubit(repo);
      },
      act: (_) async {
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => <List<Activity>>[],
    );
  });

  group('ActivityCubit CRUD Operations', () {
    test('forwards addActivity to the repository', () async {
      final repo = createMockRepo();
      final cubit = ActivityCubit(repo);
      final activity = buildActivity(id: 'a1');

      await cubit.addActivity(activity);

      verify(() => repo.addActivity(activity)).called(1);
      await cubit.close();
    });

    test('forwards updateActivity to the repository', () async {
      final repo = createMockRepo();
      final cubit = ActivityCubit(repo);
      final activity = buildActivity(id: 'a1');

      await cubit.updateActivity(activity);

      verify(() => repo.updateActivity(activity)).called(1);
      await cubit.close();
    });

    test('forwards deleteActivity to the repository', () async {
      final repo = createMockRepo();
      final cubit = ActivityCubit(repo);

      await cubit.deleteActivity('a1');

      verify(() => repo.deleteActivity('a1')).called(1);
      await cubit.close();
    });
  });

  group('ActivityCubit Detail & Notes Management', () {
    
    blocTest<ActivityCubit, List<Activity>>(
      'loadActivityDetails updates state when repository returns details',
      build: () {
        final repo = createMockRepo();
        final detailedActivity = buildActivity(id: 'a1', name: 'Updated Hike Details');
        
        when(() => repo.fetchActivityDetails('a1')).thenAnswer((_) async => detailedActivity);
        return ActivityCubit(repo);
      },
      seed: () => [buildActivity(id: 'a1', name: 'Basic Hike')],
      act: (cubit) => cubit.loadActivityDetails('a1'),
      expect: () => [
        isA<List<Activity>>()
          .having((list) => list.first.id, 'id', 'a1')
          .having((list) => list.first.name, 'name', 'Updated Hike Details')
      ],
    );

    blocTest<ActivityCubit, List<Activity>>(
      'loadActivityDetails does not alter state if activity is not found (null)',
      build: () {
        final repo = createMockRepo();
        when(() => repo.fetchActivityDetails('a1')).thenAnswer((_) async => null);
        return ActivityCubit(repo);
      },
      seed: () => [buildActivity(id: 'a1', name: 'Basic Hike')],
      act: (cubit) => cubit.loadActivityDetails('a1'),
      expect: () => <List<Activity>>[],
    );

    blocTest<ActivityCubit, List<Activity>>(
      'addOrUpdateNote adds a new note generating an ID if empty',
      build: () {
        final repo = createMockRepo();
        return ActivityCubit(repo);
      },
      seed: () => [buildActivity(id: 'a1')],
      act: (cubit) {
        final activity = cubit.state.first;
        final newNote = ActivityNote(id: '', text: 'First trail annotation', createdAt: DateTime(2026, 1, 1));
        return cubit.addOrUpdateNote(activity, newNote);
      },
      expect: () => [
        isA<List<Activity>>()
            .having((list) => list.first.notes.length, 'notes count', 1)
            .having((list) => list.first.notes.first.text, 'note text', 'First trail annotation')
            .having((list) => list.first.notes.first.id, 'note id is not empty', isNotEmpty)
      ],
    );

    blocTest<ActivityCubit, List<Activity>>(
      'addOrUpdateNote updates an existing note and saves it to repository',
      build: () {
        final repo = createMockRepo();
        return ActivityCubit(repo);
      },
      seed: () {
        final initialNote = ActivityNote(id: 'n1', text: 'Original text', createdAt: DateTime(2026, 1, 1));
        return [buildActivity(id: 'a1', notes: [initialNote])];
      },
      act: (cubit) {
        final activity = cubit.state.first;
        final updatedNote = ActivityNote(id: 'n1', text: 'Modified text', createdAt: DateTime(2026, 1, 1));
        return cubit.addOrUpdateNote(activity, updatedNote);
      },
      expect: () => [
        isA<List<Activity>>()
          .having((list) => list.first.notes.length, 'notes count', 1)
          .having((list) => list.first.notes.first.text, 'note text updated', 'Modified text')
      ],
    );

    blocTest<ActivityCubit, List<Activity>>(
      'deleteNote removes the indicated note from state and invokes repository',
      build: () {
        final repo = createMockRepo();
        return ActivityCubit(repo);
      },
      seed: () {
        final note1 = ActivityNote(id: 'n1', text: 'To keep', createdAt: DateTime(2026, 1, 1));
        final note2 = ActivityNote(id: 'n2', text: 'To delete', createdAt: DateTime(2026, 1, 1));
        return [buildActivity(id: 'a1', notes: [note1, note2])];
      },
      act: (cubit) {
        final activity = cubit.state.first;
        return cubit.deleteNote(activity, 'n2');
      },
      expect: () => [
        isA<List<Activity>>()
          .having((list) => list.first.notes.length, 'remaining notes count', 1)
          .having((list) => list.first.notes.first.id, 'kept note id', 'n1')
      ],
    );
  });

  test('close cancels the stream subscription', () async {
    final controller = StreamController<List<Activity>>();
    final repo = createMockRepo(remoteStream: controller.stream);
    final cubit = ActivityCubit(repo);

    await Future<void>.delayed(Duration.zero);
    expect(controller.hasListener, true);

    await cubit.close();
    expect(controller.hasListener, false);

    await controller.close();
  });
}