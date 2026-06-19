import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/activity_note.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

class MockTrailPoint extends Mock implements TrailPoint {}

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
        )
      ],
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

    test('copyWith updates all properties when provided', () {
      final mockPoint = MockTrailPoint();
      final copy = activity.copyWith(
        id: 'new-id',
        name: 'New Name',
        status: ActivityStatus.planned,
        date: DateTime.utc(2025),
        trailName: 'New Trail',
        distanceKm: 99.9,
        durationMinutes: 100,
        xpEarned: 50.0,
        notes: [],
        difficulty: ActivityDifficulty.hard,
        trailId: 'new-trail-id',
        trailPath: [[mockPoint]],
        trackedDistance: 15.0,
        trackedElevationGap: 300.0,
        trackedTime: const Duration(hours: 3),
      );

      expect(copy.id, 'new-id');
      expect(copy.name, 'New Name');
      expect(copy.status, ActivityStatus.planned);
      expect(copy.difficulty, ActivityDifficulty.hard);
      expect(copy.trailId, 'new-trail-id');
      expect(copy.trackedElevationGap, 300.0);
      expect(copy.trailPath.isNotEmpty, true);
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
    });

    test('hasTrailPath returns correct boolean based on segments', () {
      final emptyActivity = activity.copyWith(trailPath: []);
      expect(emptyActivity.hasTrailPath, false);

      final emptySegmentsActivity = activity.copyWith(trailPath: [[], []]);
      expect(emptySegmentsActivity.hasTrailPath, false);

      final mockPoint = MockTrailPoint();
      when(() => mockPoint.lat).thenReturn(45.0);
      when(() => mockPoint.lng).thenReturn(9.0);

      final validActivity = activity.copyWith(trailPath: [[], [mockPoint]]);
      expect(validActivity.hasTrailPath, true);
    });

    test('trailSubTrails correctly maps to LatLng and filters empty segments', () {
      final mockPoint1 = MockTrailPoint();
      when(() => mockPoint1.lat).thenReturn(45.0);
      when(() => mockPoint1.lng).thenReturn(9.0);

      final mockPoint2 = MockTrailPoint();
      when(() => mockPoint2.lat).thenReturn(46.0);
      when(() => mockPoint2.lng).thenReturn(10.0);

      final testActivity = activity.copyWith(
        trailPath: [
          [],
          [mockPoint1, mockPoint2],
        ],
      );

      final subTrails = testActivity.trailSubTrails;

      expect(subTrails.length, 1);
      expect(subTrails.first.length, 2);
      expect(subTrails.first[0], isA<LatLng>());
      expect(subTrails.first[0].latitude, 45.0);
      expect(subTrails.first[0].longitude, 9.0);
    });

    test('navigatorTrail returns correct map structure handling name fallback', () {
      final mockPoint = MockTrailPoint();
      when(() => mockPoint.lat).thenReturn(45.0);
      when(() => mockPoint.lng).thenReturn(9.0);

      final activityWithTrailName = activity.copyWith(
        name: 'Base Name',
        trailName: 'Specific Trail Name',
        trailId: 'trail-123',
        trailPath: [[mockPoint]],
      );

      final navWithTrailName = activityWithTrailName.navigatorTrail;
      expect(navWithTrailName['id'], 'trail-123');
      expect(navWithTrailName['name'], 'Specific Trail Name');
      expect(navWithTrailName['subTrails'].length, 1);

      final activityWithoutTrailName = activity.copyWith(
        name: 'Base Name',
        trailName: '',
        trailId: 'trail-456',
        trailPath: [],
      );

      final navWithoutTrailName = activityWithoutTrailName.navigatorTrail;
      expect(navWithoutTrailName['name'], 'Base Name');
    });

    test('ActivityDifficultyExtension.label returns correct string representations', () {
      expect(ActivityDifficulty.easy.label, 'Beginner');
      expect(ActivityDifficulty.moderate.label, 'Intermediate');
      expect(ActivityDifficulty.hard.label, 'Expert');
    });
  });
}