import 'package:application/core/models/activity_note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityStatus { completed, planned }

enum ActivityDifficulty { easy, moderate, hard }

class Activity {
  String id;
  String name;
  ActivityStatus status;
  DateTime date;
  String trailName;
  double distanceKm;
  int durationMinutes;
  double xpEarned;
  List<ActivityNote> notes;
  ActivityDifficulty difficulty;
  String trailId;
  double trackedDistance;
  double trackedElevationGap;
  Duration trackedTime;
  bool pendingSync;

  Activity({
    this.id = '',
    required this.name,
    required this.status,
    required this.date,
    this.trailName = '',
    this.distanceKm = 0,
    this.durationMinutes = 0,
    this.xpEarned = 0,
    List<ActivityNote> notes = const [],
    this.difficulty = ActivityDifficulty.easy,
    this.trailId = '',
    this.trackedDistance = 0,
    this.trackedElevationGap = 0,
    this.trackedTime = Duration.zero,
    this.pendingSync = false,
  }) : notes = List<ActivityNote>.from(notes);

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.name,
    'date': Timestamp.fromDate(date),
    'trailName': trailName,
    'distanceKm': distanceKm,
    'durationMinutes': durationMinutes,
    'xpEarned': xpEarned,
    'notes': notes.map((note) => note.toJson()).toList(),
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
      notes:
          (json['notes'] as List<dynamic>?)
              ?.map(
                (noteJson) => ActivityNote.fromJson(
                  Map<String, dynamic>.from(noteJson as Map),
                ),
              )
              .toList() ??
          const [],
      difficulty: ActivityDifficulty.values.byName(
        json['difficulty'] ?? 'easy',
      ),
      trailId: json['trailId']?.toString() ?? '',
      trackedDistance: (json['trackedDistance'] ?? 0).toDouble(),
      trackedElevationGap: json['trackedElevationGap'] ?? 0,
      trackedTime: Duration(seconds: json['trackedTime'] ?? 0),
      pendingSync: false,
    );
  }
}

extension ActivityDifficultyExtension on ActivityDifficulty {
  String get label {
    switch (this) {
      case ActivityDifficulty.easy:
        return 'Beginner';
      case ActivityDifficulty.moderate:
        return 'Intermediate';
      case ActivityDifficulty.hard:
        return 'Expert';
    }
  }
}
