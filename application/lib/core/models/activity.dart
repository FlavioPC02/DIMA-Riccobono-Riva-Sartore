import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityStatus { completed, planned }

class Activity {
  final String id;
  final String name;
  final ActivityStatus status;
  final DateTime date;
  final String trailName;
  final double distanceKm;
  final int durationMinutes;
  final double xpEarned;
  final String notes;

  const Activity({
    required this.id,
    required this.name,
    required this.status,
    required this.date,
    this.trailName = '',
    this.distanceKm = 0,
    this.durationMinutes = 0,
    this.xpEarned = 0,
    this.notes = '',
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
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.name,
    'date': Timestamp.fromDate(date),
    'trailName': trailName,
    'distanceKm': distanceKm,
    'durationMinutes': durationMinutes,
    'xpEarned': xpEarned,
    'notes': notes,
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
    );
  }
}
