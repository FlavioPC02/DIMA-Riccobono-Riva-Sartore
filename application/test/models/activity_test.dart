import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/activity_note.dart';

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
      notes: [
        ActivityNote(
          id: 'note-1',
          text: 'Beautiful day',
          imageUrls: const [],
          createdAt: date,
        ),
      ],
      difficulty: ActivityDifficulty.moderate,
      trackedDistance: 12.0,
      trackedElevationGap: 200,
      trackedTime: const Duration(hours: 2),
    );

    test('properties can be updated directly', () {
      final mutableActivity = Activity(
        id: activity.id,
        name: activity.name,
        status: activity.status,
        date: activity.date,
      );

      mutableActivity.name = 'Evening Hike';
      mutableActivity.distanceKm = 10.0;
      mutableActivity.status = ActivityStatus.planned;

      expect(mutableActivity.id, activity.id);
      expect(mutableActivity.name, 'Evening Hike');
      expect(mutableActivity.distanceKm, 10.0);
      expect(mutableActivity.status, ActivityStatus.planned);
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
      expect(parsed.notes.isNotEmpty, true);
      expect(parsed.notes.first.text, 'Beautiful day');
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
      expect(parsed.notes, isEmpty);
      expect(parsed.difficulty, ActivityDifficulty.easy);
      expect(parsed.trackedTime, Duration.zero);
      expect(parsed.trackedDistance, 0);
      expect(parsed.trackedElevationGap, 0);
      expect(parsed.trackedTime, Duration.zero);
    });

    test(
      'ActivityDifficultyExtension.label returns correct string representations',
      () {
        expect(ActivityDifficulty.easy.label, 'Beginner');
        expect(ActivityDifficulty.moderate.label, 'Intermediate');
        expect(ActivityDifficulty.hard.label, 'Expert');
      },
    );
  });
}
