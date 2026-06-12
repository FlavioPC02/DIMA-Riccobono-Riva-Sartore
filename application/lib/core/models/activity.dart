import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import 'trail_point.dart';

enum ActivityStatus { completed, planned }

enum ActivityDifficulty { easy, moderate, hard }

class Activity {
  final String id;
  final String name;
  ActivityStatus status;
  final DateTime date;
  final String trailName;
  final double distanceKm;
  final int durationMinutes;
  final double xpEarned;
  final String notes;
  final ActivityDifficulty difficulty;
  final String trailId;
  final List<List<TrailPoint>> trailPath;
  double trackedDistance;
  double trackedElevationGap;
  Duration trackedTime;

  Activity({
    this.id = '',
    required this.name,
    required this.status,
    required this.date,
    this.trailName = '',
    this.distanceKm = 0,
    this.durationMinutes = 0,
    this.xpEarned = 0,
    this.notes = '',
    this.difficulty = ActivityDifficulty.easy,
    this.trailId = '',
    this.trailPath = const [],
    this.trackedDistance = 0,
    this.trackedElevationGap = 0,
    this.trackedTime = Duration.zero,
  });

  Activity copyWith({
    String? id,
    String? name,
    ActivityStatus? status,
    DateTime? date,
    String? trailName,
    double? distanceKm,
    int? durationMinutes,
    double? xpEarned,
    String? notes,
    ActivityDifficulty? difficulty,
    String? trailId,
    List<List<TrailPoint>>? trailPath,
    double? trackedDistance,
    double? trackedElevationGap,
    Duration? trackedTime,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      date: date ?? this.date,
      trailName: trailName ?? this.trailName,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      xpEarned: xpEarned ?? this.xpEarned,
      notes: notes ?? this.notes,
      difficulty: difficulty ?? this.difficulty,
      trailId: trailId ?? this.trailId,
      trailPath: trailPath ?? this.trailPath,
      trackedDistance: trackedDistance ?? this.trackedDistance,
      trackedElevationGap: trackedElevationGap ?? this.trackedElevationGap,
      trackedTime: trackedTime ?? this.trackedTime,
    );
  }

  bool get hasTrailPath => trailPath.any((segment) => segment.isNotEmpty);

  List<List<LatLng>> get trailSubTrails {
    return trailPath
        .map(
          (segment) => segment
              .map((point) => LatLng(point.lat, point.lng))
              .toList(growable: false),
        )
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> get navigatorTrail => {
    'id': trailId,
    'name': trailName.isNotEmpty ? trailName : name,
    'subTrails': trailSubTrails,
  };

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.name,
    'date': Timestamp.fromDate(date),
    'trailName': trailName,
    'distanceKm': distanceKm,
    'durationMinutes': durationMinutes,
    'xpEarned': xpEarned,
    'notes': notes,
    'difficulty': difficulty.name,
    'trailId': trailId,
    'trackedDistance': trackedDistance,
    'trackedElevationGap': trackedElevationGap,
    'trackedTime': trackedTime.inSeconds,
  };

  factory Activity.fromJson(String id, Map<String, dynamic> json) {
    return Activity(
      id: id,
      name: json['name'] ?? '',
      status: ActivityStatus.values.byName(json['status'] ?? 'planned'),
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      trailName: json['trailName'] ?? '',
      distanceKm: (json['distanceKm'] ?? 0).toDouble(),
      durationMinutes: json['durationMinutes'] ?? 0,
      xpEarned: (json['xpEarned'] ?? 0).toDouble(),
      notes: json['notes'] ?? '',
      difficulty: ActivityDifficulty.values.byName(
        json['difficulty'] ?? 'easy',
      ),
      trailId: json['trailId']?.toString() ?? '',
      trackedDistance: json['trackedDistance'] ?? 0,
      trackedElevationGap: json['trackedElevationGap'] ?? 0,
      trackedTime: Duration(seconds: json['trackedTime'] ?? 0),
    );
  }
}
