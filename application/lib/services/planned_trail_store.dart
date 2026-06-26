import 'package:application/core/models/planned_trail.dart';
import 'package:hive_ce_flutter/adapters.dart';

abstract class PlannedTrailLocalDataSource {
  Future<void> saveTrail(PlannedTrail trail);

  Future<PlannedTrail?> getTrail(String activityId);

  Future<void> deleteTrail(String activityId);

  Future<void> clear();

  Stream<Set<String>> watchDownloadedTrailIds();
}

class PlannedTrailStore implements PlannedTrailLocalDataSource {
  static const String _boxName = 'planned_trails';

  Box<Map>? _box;

  Future<Box<Map>> _plannedTrailBox() async {
    if (_box != null) return _box!;

    _box = await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  @override
  Stream<Set<String>> watchDownloadedTrailIds() {
    return Stream<Set<String>>.multi((controller) async {
      final box = await _plannedTrailBox();

      Set<String> readIds() {
        return box.keys.map((key) => key.toString()).toSet();
      }

      controller.add(readIds());

      final subscription = box.watch().listen(
        (_) => controller.add(readIds()),
        onError: controller.addError,
        onDone: controller.close,
      );

      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> saveTrail(PlannedTrail trail) async {
    final box = await _plannedTrailBox();

    await box.put(trail.activityId, trail.toMap());
  }

  @override
  Future<PlannedTrail?> getTrail(String activityId) async {
    final box = await _plannedTrailBox();
    final map = box.get(activityId);

    if (map == null) return null;

    return PlannedTrail.fromMap(map);
  }

  @override
  Future<void> deleteTrail(String activityId) async {
    final box = await _plannedTrailBox();

    await box.delete(activityId);
  }

  @override
  Future<void> clear() async {
    final box = await _plannedTrailBox();
    await box.clear();
  }
}
