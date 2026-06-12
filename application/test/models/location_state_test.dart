import 'package:flutter_test/flutter_test.dart';
import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/models/location_point.dart';

void main() {
  group('LocationState', () {
    test('idle state default labels and flags', () {
      final state = const LocationState.idle();

      expect(state.kind, LocationStateKind.idle);
      expect(state.isTracking, isFalse);
      expect(state.isError, isFalse);
      expect(state.getDistanceLabel(), '--');
      expect(state.getElevationGapLabel(), '--');
      expect(state.totalAscentLabel, '+0.0 m');
      expect(state.totalDescentLabel, '+0.0 m');
    });

    test('tracking state labels show formatted distance and elevation', () {
      final points = [
        LocationPoint(
          lat: 45.0,
          lng: 9.0,
          altitude: 100.0,
          positionAccuracy: 1.0,
          altitudeAccuracy: 1.0,
          timestamp: DateTime.utc(2024, 1, 1),
        ),
      ];
      final state = LocationState.tracking(
        points: points,
        current: points.first,
        distance: 1523,
        elevationGap: -5.12,
        totalAscent: 150.4,
        totalDescent: 60.7,
      );

      expect(state.kind, LocationStateKind.tracking);
      expect(state.isTracking, isTrue);
      expect(state.isError, isFalse);
      expect(state.getDistanceLabel(), '1.52 km');
      expect(state.getElevationGapLabel(), '--5.1 m');
      expect(state.totalAscentLabel, '+150.4 m');
      expect(state.totalDescentLabel, '+60.7 m');
    });

    test('error state sets isError and stores a message', () {
      final state = LocationState.error('fail');

      expect(state.kind, LocationStateKind.error);
      expect(state.isError, isTrue);
      expect(state.errorMessage, 'fail');
    });

    test('props implementation supports equality comparison', () {
      final a = LocationState.tracking(
        points: const [],
        current: null,
        distance: 0,
        elevationGap: 1,
        totalAscent: 1,
        totalDescent: 2,
      );
      final b = LocationState.tracking(
        points: const [],
        current: null,
        distance: 0,
        elevationGap: 1,
        totalAscent: 1,
        totalDescent: 2,
      );

      expect(a, equals(b));
    });
  });
}
