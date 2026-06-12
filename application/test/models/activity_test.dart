import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/core/models/activity.dart';

void main() {
  group('Activity', () {
    final date = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final activity = Activity(
      id: 'abc',
      name: 'Morning Hike',
      status: ActivityStatus.completed,
      date: date,
      trailName: 'Trail A',
      distanceKm: 12.3,
      durationMinutes: 95,
      xpEarned: 42.0,
      notes: 'Beautiful day',
      difficulty: ActivityDifficulty.moderate,
      trackedDistance: 12.0,
      trackedElevationGap: 200,
      trackedTime: const Duration(hours: 2),
    );

    test('copyWith updates only the provided fields', () {
      final copy = activity.copyWith(
        name: 'Evening Hike',
        distanceKm: 10.0,
      );

      expect(copy.id, activity.id);
      expect(copy.name, 'Evening Hike');
      expect(copy.distanceKm, 10.0);
      expect(copy.trailName, activity.trailName);
      expect(copy.trackedTime, activity.trackedTime);
    });

    test('toJson and fromJson preserve values', () {
      final json = activity.toJson();
      expect(json['name'], 'Morning Hike');
      expect(json['status'], 'completed');
      expect(json['difficulty'], 'moderate');
      expect(json['trackedTime'], 7200);

      final parsed = Activity.fromJson('abc', json);
      expect(parsed.id, 'abc');
      expect(parsed.name, 'Morning Hike');
      expect(parsed.status, ActivityStatus.completed);
      expect(parsed.difficulty, ActivityDifficulty.moderate);
      expect(parsed.trackedTime, const Duration(hours: 2));
    });

    test('fromJson handles missing optional values and uses defaults', () {
      final partial = {
        'name': 'Partial Hike',
        'status': 'planned',
        'date': Timestamp.fromDate(date),
      };

      final parsed = Activity.fromJson('partial', partial);
      expect(parsed.id, 'partial');
      expect(parsed.name, 'Partial Hike');
      expect(parsed.trailName, '');
      expect(parsed.distanceKm, 0);
      expect(parsed.durationMinutes, 0);
      expect(parsed.notes, '');
      expect(parsed.difficulty, ActivityDifficulty.easy);
      expect(parsed.trackedTime, Duration.zero);
    });
  });
}
