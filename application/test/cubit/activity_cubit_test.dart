import 'dart:async';

import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

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
  String notes = 'notes',
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
    notes: notes,
    difficulty: difficulty,
    trackedDistance: trackedDistance,
    trackedElevationGap: trackedElevationGap,
    trackedTime: trackedTime,
  );
}

void main() {
  setUpAll(() {
    setupTest();
  });

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
