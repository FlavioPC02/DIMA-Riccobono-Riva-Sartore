import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('formats durations and distances for watch-friendly labels', () {
    expect(const Duration(minutes: 1, seconds: 5).toCompactLabel(), '1m 5s');
    expect(25.toMinuteDurationLabel(), '25m');
    expect(formatDistanceMeters(0), '0 m');
    expect(formatDistanceMeters(1450), '1.45 km');
    expect(formatElevationGapMeters(12.34), '+12.3 m');
  });

  test('computes trail length and bearing', () {
    final trail = [
      [const LatLng(0, 0), const LatLng(0, 0.001)],
      [const LatLng(0, 0.001), const LatLng(0.001, 0.001)],
    ];

    final length = HikeTrailGeometry.trailLengthMeters(trail);

    expect(length, closeTo(222.64, 1.0));
    expect(
      HikeTrailGeometry.bearingDegrees(const LatLng(0, 0), const LatLng(1, 0)),
      closeTo(0, 0.1),
    );
  });

  test('off trail detector respects threshold and cooldown', () {
    final detector = HikeOffTrailDetector(
      thresholdMeters: 50,
      cooldown: const Duration(seconds: 60),
    );
    final trail = [
      [const LatLng(0, 0), const LatLng(0, 0.001)],
    ];

    final warning = detector.evaluate(
      position: const LatLng(0.001, 0.001),
      subTrails: trail,
      now: DateTime.fromMillisecondsSinceEpoch(0),
    );

    expect(warning, isNotNull);
    expect(warning!.distanceMeters, greaterThan(50));

    final suppressed = detector.evaluate(
      position: const LatLng(0.001, 0.001),
      subTrails: trail,
      now: DateTime.fromMillisecondsSinceEpoch(10 * 1000),
    );

    expect(suppressed, isNull);
  });

  test('live stats serialise round trip', () {
    final stats = HikeLiveStats(
      elapsedTime: const Duration(minutes: 14, seconds: 20),
      distanceMeters: 1350,
      elevationGapMeters: 42.4,
      eta: DateTime.fromMillisecondsSinceEpoch(1000),
      recordingState: HikeRecordingState.recording,
      trailProgress: const HikeTrailProgress(
        travelledMeters: 2.3,
        trailDistanceMeters: 6.1,
        bearingDegrees: 180,
      ),
      offTrailWarning: HikeOffTrailWarning(
        distanceMeters: 58,
        direction: 'Move to the left to get back on the trail',
        triggeredAt: DateTime.fromMillisecondsSinceEpoch(2000),
      ),
      currentLocation: const LatLng(45.1, 7.2),
      nextWaypoint: const LatLng(45.2, 7.3),
    );

    final restored = HikeLiveStats.fromMap(stats.toMap());

    expect(restored.elapsedTime, stats.elapsedTime);
    expect(restored.distanceMeters, stats.distanceMeters);
    expect(restored.elevationGapMeters, stats.elevationGapMeters);
    expect(restored.recordingState, stats.recordingState);
    expect(restored.trailProgress?.progressFraction, closeTo(0.377, 0.01));
    expect(restored.offTrailWarning?.distanceMeters, 58);
    expect(restored.currentLocation, stats.currentLocation);
  });

  testWidgets('rendered widgets build without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: HikeMetricScreen.distance(
                  distanceMeters: 1234,
                ),
              ),
              HikeRecordingControls(
                state: HikeRecordingState.paused,
                onStart: () {},
                onPause: () {},
                onStop: () {},
              ),
              HikeOffTrailBanner(
                distanceMeters: 80,
                direction: 'Move right',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Off trail'), findsOneWidget);
  });
}