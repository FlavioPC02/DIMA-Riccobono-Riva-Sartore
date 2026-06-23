import 'dart:io';
import 'package:application/core/models/planned_trail.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:application/services/planned_trail_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('planned_trail_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });
  test('saves, reads and deletes a planned trail', () async {
    final store = PlannedTrailStore();

    final trail = PlannedTrail(
      activityId: 'activity_123',
      trailId: 'trail_456',
      segments: const [
        [TrailPoint(lat: 45.1, lng: 9.1), TrailPoint(lat: 45.2, lng: 9.2)],
        [TrailPoint(lat: 45.3, lng: 9.3)],
      ],
    );

    await store.saveTrail(trail);

    final restored = await store.getTrail('activity_123');

    expect(restored, isNotNull);
    expect(restored!.activityId, 'activity_123');
    expect(restored.trailId, 'trail_456');
    expect(restored.segments.length, 2);
    expect(restored.segments.first.first.lat, 45.1);
    expect(restored.segments.first.first.lng, 9.1);

    await store.deleteTrail('activity_123');

    expect(await store.getTrail('activity_123'), isNull);
  });
}
