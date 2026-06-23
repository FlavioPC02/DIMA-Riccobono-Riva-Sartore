import 'package:application/core/models/planned_trail.dart';
import 'package:hive_ce_flutter/adapters.dart';

abstract class PlannedTrailLocalDataSource {
  Future<void> saveTrail(PlannedTrail trail);

  Future<PlannedTrail?> getTrail(String activityId);

  Future<void> deleteTrail(String activityId);
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
  Future<void> saveTrail(PlannedTrail trail) async {
    final box = await _plannedTrailBox();

    await box.put(
      trail.activityId,
      trail.toMap(),
      );
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
}