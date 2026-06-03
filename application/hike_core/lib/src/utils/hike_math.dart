import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/hike_off_trail_warning.dart';

class HikeTrailGeometry {
  static const double earthRadiusMeters = 6371000;

  static double trailLengthMeters(List<List<LatLng>> subTrails) {
    double total = 0;

    for (final segment in subTrails) {
      if (segment.length < 2) continue;

      for (var index = 0; index < segment.length - 1; index++) {
        total += _distance(segment[index], segment[index + 1]);
      }
    }

    return total;
  }

  static double? bearingDegrees(LatLng from, LatLng to) {
    final lat1 = _degToRad(from.latitude);
    final lat2 = _degToRad(to.latitude);
    final deltaLng = _degToRad(to.longitude - from.longitude);

    final y = math.sin(deltaLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);

    if (x == 0 && y == 0) return null;

    final bearing = math.atan2(y, x);
    return (radToDeg(bearing) + 360) % 360;
  }

  static double distanceToSegmentMeters(LatLng point, LatLng a, LatLng b) {
    final projection = _project(point, a, b);
    return _distance(point, projection.projectedPoint);
  }

  static (double distance, double side) distanceAndSideToSegment(
    LatLng point,
    LatLng a,
    LatLng b,
  ) {
    final projection = _project(point, a, b);
    return (_distance(point, projection.projectedPoint), projection.side);
  }

  static double _distance(LatLng a, LatLng b) {
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final haversine =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  static _ProjectionResult _project(LatLng point, LatLng a, LatLng b) {
    final px = _lonToX(point.longitude);
    final py = _latToY(point.latitude);
    final ax = _lonToX(a.longitude);
    final ay = _latToY(a.latitude);
    final bx = _lonToX(b.longitude);
    final by = _latToY(b.latitude);

    final dx = bx - ax;
    final dy = by - ay;

    if (dx == 0 && dy == 0) {
      return _ProjectionResult(
        projectedPoint: a,
        side: 0,
      );
    }

    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final tt = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
    final projx = ax + tt * dx;
    final projy = ay + tt * dy;

    final projectedPoint = LatLng(
      _yToLat(projy),
      _xToLon(projx),
    );

    final side = dx * (py - projy) - dy * (px - projx);
    return _ProjectionResult(projectedPoint: projectedPoint, side: side);
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  static double radToDeg(double rad) => rad * (180.0 / math.pi);

  static double _lonToX(double lon) => _degToRad(lon) * earthRadiusMeters;

  static double _latToY(double lat) =>
      math.log(math.tan((math.pi / 4) + (_degToRad(lat) / 2))) * earthRadiusMeters;

  static double _xToLon(double x) => radToDeg(x / earthRadiusMeters);

  static double _yToLat(double y) =>
      radToDeg(2 * math.atan(math.exp(y / earthRadiusMeters)) - (math.pi / 2));
}

class HikeOffTrailDetector {
  final double thresholdMeters;
  final Duration cooldown;
  DateTime? _lastWarningAt;

  HikeOffTrailDetector({
    this.thresholdMeters = 50,
    this.cooldown = const Duration(seconds: 60),
  });

  HikeOffTrailWarning? evaluate({
    required LatLng position,
    required List<List<LatLng>> subTrails,
    required DateTime now,
  }) {
    if (subTrails.isEmpty) return null;

    double minDistance = double.infinity;
    double sideForMin = 0.0;

    for (final segment in subTrails) {
      if (segment.length < 2) continue;

      for (var index = 0; index < segment.length - 1; index++) {
        final (distance, side) = HikeTrailGeometry.distanceAndSideToSegment(
          position,
          segment[index],
          segment[index + 1],
        );
        if (distance < minDistance) {
          minDistance = distance;
          sideForMin = side;
        }
      }
    }

    final distanceMeters = minDistance.isFinite ? minDistance.round() : 0;
    final lastWarningAt = _lastWarningAt;
    final canWarnAgain =
        lastWarningAt == null || now.difference(lastWarningAt) >= cooldown;

    if (distanceMeters <= thresholdMeters || !canWarnAgain) {
      return null;
    }

    _lastWarningAt = now;

    final direction = _directionFromSide(sideForMin);
    return HikeOffTrailWarning(
      distanceMeters: distanceMeters,
      direction: direction,
      triggeredAt: now,
    );
  }

  void reset() {
    _lastWarningAt = null;
  }

  String _directionFromSide(double side) {
    if (side > 0.0) {
      return 'Move to the right to get back on the trail';
    }

    if (side < 0.0) {
      return 'Move to the left to get back on the trail';
    }

    return 'Get closer to the trail';
  }
}

class _ProjectionResult {
  final LatLng projectedPoint;
  final double side;

  const _ProjectionResult({required this.projectedPoint, required this.side});
}