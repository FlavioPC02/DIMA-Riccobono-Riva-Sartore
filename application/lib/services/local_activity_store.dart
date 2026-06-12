import 'dart:async';
import 'dart:convert';

import 'package:application/core/models/activity.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:sqflite/sqflite.dart';

abstract class ActivityLocalDataSource {
  Stream<List<Activity>> streamActivities();
  Future<String> upsertActivity(Activity activity);
  Future<void> deleteActivity(String id);
  String createId();
}

class SqliteActivityStore implements ActivityLocalDataSource {
  static const _databaseName = 'offline_activities.db';
  static const _databaseVersion = 1;
  static const _tableName = 'activities';

  Database? _database;
  final _updates = StreamController<List<Activity>>.broadcast();

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;

    final databasesPath = await getDatabasesPath();
    final path = '$databasesPath/$_databaseName';

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE $_tableName (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  status TEXT NOT NULL,
  date_millis INTEGER NOT NULL,
  trail_name TEXT NOT NULL,
  trail_id TEXT NOT NULL,
  distance_km REAL NOT NULL,
  duration_minutes INTEGER NOT NULL,
  xp_earned REAL NOT NULL,
  notes TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  tracked_distance REAL NOT NULL,
  tracked_elevation_gap REAL NOT NULL,
  tracked_time_seconds INTEGER NOT NULL,
  trail_path_json TEXT NOT NULL
)
''');
      },
    );

    return _database!;
  }

  @override
  String createId() => 'local_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Stream<List<Activity>> streamActivities() async* {
    yield await fetchActivities();
    yield* _updates.stream;
  }

  Future<List<Activity>> fetchActivities() async {
    final db = await _db;
    final rows = await db.query(_tableName, orderBy: 'date_millis DESC');
    return rows.map(_activityFromRow).toList(growable: false);
  }

  @override
  Future<String> upsertActivity(Activity activity) async {
    final id = activity.id.isEmpty ? createId() : activity.id;
    final db = await _db;
    await db.insert(
      _tableName,
      _activityToRow(activity.copyWith(id: id)),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _emitUpdates();
    return id;
  }

  @override
  Future<void> deleteActivity(String id) async {
    final db = await _db;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    await _emitUpdates();
  }

  Future<void> _emitUpdates() async {
    if (_updates.isClosed) return;
    _updates.add(await fetchActivities());
  }

  Map<String, Object?> _activityToRow(Activity activity) {
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

  Activity _activityFromRow(Map<String, Object?> row) {
    return Activity(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      status: ActivityStatus.values.byName(
        row['status']?.toString() ?? ActivityStatus.planned.name,
      ),
      date: DateTime.fromMillisecondsSinceEpoch(
        (row['date_millis'] as num?)?.toInt() ?? 0,
      ),
      trailName: row['trail_name']?.toString() ?? '',
      trailId: row['trail_id']?.toString() ?? '',
      distanceKm: (row['distance_km'] as num?)?.toDouble() ?? 0,
      durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 0,
      xpEarned: (row['xp_earned'] as num?)?.toDouble() ?? 0,
      notes: row['notes']?.toString() ?? '',
      difficulty: ActivityDifficulty.values.byName(
        row['difficulty']?.toString() ?? ActivityDifficulty.easy.name,
      ),
      trackedDistance: (row['tracked_distance'] as num?)?.toDouble() ?? 0,
      trackedElevationGap:
          (row['tracked_elevation_gap'] as num?)?.toDouble() ?? 0,
      trackedTime: Duration(
        seconds: (row['tracked_time_seconds'] as num?)?.toInt() ?? 0,
      ),
      trailPath: _decodeTrailPath(row['trail_path_json']?.toString()),
    );
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
