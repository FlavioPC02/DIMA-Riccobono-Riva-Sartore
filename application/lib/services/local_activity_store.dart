import 'dart:async';
import 'dart:convert';

import 'package:application/core/models/activity.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:hive_ce_flutter/adapters.dart';

abstract class ActivityLocalDataSource {
  Stream<List<Activity>> streamActivities();
  Future<String> upsertActivity(Activity activity);
  Future<void> deleteActivity(String id);
  String createId();
}

class HiveActivityStore implements ActivityLocalDataSource {
  static const _boxName = 'offline_activities';

  Box<Map>? _box;
  final _updates = StreamController<List<Activity>>.broadcast();

  Future<Box<Map>> get _activityBox async {
    final existing = _box;
    if (existing != null) return existing;

    _box = await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  @override
  String createId() => 'local_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Stream<List<Activity>> streamActivities() async* {
    yield await fetchActivities();
    yield* _updates.stream;
  }

  Future<List<Activity>> fetchActivities() async {
    final box = await _activityBox;
    final activities = box.values
        .map((entry) => _activityFromEntry(_normalizeEntry(entry)))
        .toList(growable: false);
    activities.sort((a, b) => b.date.compareTo(a.date));
    return activities;
  }

  @override
  Future<String> upsertActivity(Activity activity) async {
    final id = activity.id.isEmpty ? createId() : activity.id;
    final box = await _activityBox;
    await box.put(id, _activityToEntry(activity.copyWith(id: id)));
    await _emitUpdates();
    return id;
  }

  @override
  Future<void> deleteActivity(String id) async {
    final box = await _activityBox;
    await box.delete(id);
    await _emitUpdates();
  }

  Future<void> _emitUpdates() async {
    if (_updates.isClosed) return;
    _updates.add(await fetchActivities());
  }

  Map<String, Object?> _activityToEntry(Activity activity) {
    return {
      'id': activity.id,
      'name': activity.name,
      'status': activity.status.name,
      'date_millis': activity.date.millisecondsSinceEpoch,
      'trail_name': activity.trailName,
      'trail_id': activity.trailId,
      'distance_km': activity.distanceKm,
      'duration_minutes': activity.durationMinutes,
      'xp_earned': activity.xpEarned,
      'notes': activity.notes,
      'difficulty': activity.difficulty.name,
      'tracked_distance': activity.trackedDistance,
      'tracked_elevation_gap': activity.trackedElevationGap,
      'tracked_time_seconds': activity.trackedTime.inSeconds,
      'trail_path_json': _encodeTrailPath(activity.trailPath),
    };
  }

  Activity _activityFromEntry(Map<String, Object?> entry) {
    return Activity(
      id: entry['id']?.toString() ?? '',
      name: entry['name']?.toString() ?? '',
      status: ActivityStatus.values.byName(
        entry['status']?.toString() ?? ActivityStatus.planned.name,
      ),
      date: DateTime.fromMillisecondsSinceEpoch(
        (entry['date_millis'] as num?)?.toInt() ?? 0,
      ),
      trailName: entry['trail_name']?.toString() ?? '',
      trailId: entry['trail_id']?.toString() ?? '',
      distanceKm: (entry['distance_km'] as num?)?.toDouble() ?? 0,
      durationMinutes: (entry['duration_minutes'] as num?)?.toInt() ?? 0,
      xpEarned: (entry['xp_earned'] as num?)?.toDouble() ?? 0,
      notes: entry['notes']?.toString() ?? '',
      difficulty: ActivityDifficulty.values.byName(
        entry['difficulty']?.toString() ?? ActivityDifficulty.easy.name,
      ),
      trackedDistance: (entry['tracked_distance'] as num?)?.toDouble() ?? 0,
      trackedElevationGap:
          (entry['tracked_elevation_gap'] as num?)?.toDouble() ?? 0,
      trackedTime: Duration(
        seconds: (entry['tracked_time_seconds'] as num?)?.toInt() ?? 0,
      ),
      trailPath: _decodeTrailPath(entry['trail_path_json']?.toString()),
    );
  }

  Map<String, Object?> _normalizeEntry(Map entry) {
    return entry.map((key, value) => MapEntry(key.toString(), value));
  }

  String _encodeTrailPath(List<List<TrailPoint>> trailPath) {
    return jsonEncode(
      trailPath
          .map((segment) => segment.map((point) => point.toJson()).toList())
          .toList(),
    );
  }

  List<List<TrailPoint>> _decodeTrailPath(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];

    final decoded = jsonDecode(encoded);
    if (decoded is! List) return const [];

    return decoded
        .whereType<List>()
        .map(
          (segment) => segment
              .whereType<Map>()
              .map(
                (point) => TrailPoint.fromJson(
                  point.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        )
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
  }
}
