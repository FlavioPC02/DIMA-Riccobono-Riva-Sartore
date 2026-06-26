import 'dart:io';

import 'package:application/core/models/activity.dart';
import 'package:application/core/models/activity_note.dart';
import 'package:application/services/local_activity_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('activity_hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Activity buildActivity({
    String id = '',
    required String name,
    required DateTime date,
  }) {
    return Activity(
      id: id,
      name: name,
      status: ActivityStatus.planned,
      date: date,
      trailName: 'Trail',
      trailId: 'trail-1',
      distanceKm: 4.5,
      durationMinutes: 75,
      xpEarned: 30,
      notes: [
        ActivityNote(
          id: 'note_1',
          text: 'Bring water',
          imageUrls: const [],
          createdAt: date,
        ),
      ],
      difficulty: ActivityDifficulty.moderate,
      trackedDistance: 4.2,
      trackedElevationGap: 120,
      trackedTime: const Duration(minutes: 70),
      pendingSync: true,
    );
  }

  test('persists activities in Hive and returns them newest first', () async {
    final store = HiveActivityStore();

    final olderId = await store.upsertActivity(
      buildActivity(name: 'Older', date: DateTime(2026)),
    );
    final newerId = await store.upsertActivity(
      buildActivity(name: 'Newer', date: DateTime(2026, 2)),
    );

    expect(olderId, startsWith('local_'));
    expect(newerId, startsWith('local_'));

    final restoredStore = HiveActivityStore();
    final activities = await restoredStore.fetchActivities();

    expect(activities.map((a) => a.name), ['Newer', 'Older']);
    expect(activities.first.trackedTime, const Duration(minutes: 70));
    expect(activities.first.pendingSync, isTrue);
  });

  test('updates and deletes activities by id', () async {
    final store = HiveActivityStore();
    final activity = buildActivity(
      id: 'activity-1',
      name: 'Original',
      date: DateTime(2026),
    );

    await store.upsertActivity(activity);
    activity.name = 'Updated';
    await store.upsertActivity(activity);

    var activities = await store.fetchActivities();
    expect(activities, hasLength(1));
    expect(activities.single.name, 'Updated');

    await store.deleteActivity('activity-1');

    activities = await store.fetchActivities();
    expect(activities, isEmpty);
  });
}
