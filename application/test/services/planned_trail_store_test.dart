import 'dart:io';
import 'package:application/core/models/planned_trail.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:application/services/planned_trail_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'dart:async';

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

  test('emits downloaded trail ids after save and delete', () async {
    final store = PlannedTrailStore();
    final iterator = StreamIterator(store.watchDownloadedTrailIds());

    addTearDown(iterator.cancel);

    await iterator.moveNext();
    expect(iterator.current, isEmpty);

    final trail = PlannedTrail(
      activityId: 'activity_123',
      trailId: 'trail_456',
      segments: const [
        [TrailPoint(lat: 45.1, lng: 9.1)],
      ],
    );

    final savedEmission = iterator.moveNext();
    await Future<void>.delayed(Duration.zero);
    await store.saveTrail(trail);

    expect(await savedEmission, isTrue);
    expect(iterator.current, contains('activity_123'));

    final deletedEmission = iterator.moveNext();
    await Future<void>.delayed(Duration.zero);
    await store.deleteTrail('activity_123');

    expect(await deletedEmission, isTrue);
    expect(iterator.current, isNot(contains('activity_123')));
  });

  test('clear removes all trails and emits an empty id set', () async {
    final store = PlannedTrailStore();
    final iterator = StreamIterator(store.watchDownloadedTrailIds());

    addTearDown(iterator.cancel);

    await iterator.moveNext();
    expect(iterator.current, isEmpty);

    await store.saveTrail(
      PlannedTrail(
        activityId: 'activity_123',
        trailId: 'trail_456',
        segments: const [
          [TrailPoint(lat: 45.1, lng: 9.1)],
        ],
      ),
    );

    await iterator.moveNext();
    expect(iterator.current, contains('activity_123'));

    final clearedEmission = iterator.moveNext();
    await Future<void>.delayed(Duration.zero);
    await store.clear();

    expect(await clearedEmission, isTrue);
    expect(iterator.current, isEmpty);
    expect(await store.getTrail('activity_123'), isNull);
  });

  test('allows the same stream to be listened to more than once', () async {
    final store = PlannedTrailStore();
    final stream = store.watchDownloadedTrailIds();

    expect(await stream.first, isEmpty);
    expect(await stream.first, isEmpty);
  });
}
