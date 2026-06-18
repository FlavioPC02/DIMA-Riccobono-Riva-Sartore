import 'package:application/core/models/trail_point.dart';
import 'package:latlong2/latlong.dart';

class FavoriteTrail {
  final String id;
  final String name;
  final List<List<TrailPoint>> trailPath;

  final String? distance;
  final String? duration;
  final int? difficulty;
  final String? ascent;
  final bool? isFerrata;

  const FavoriteTrail({
    required this.id,
    required this.name,
    required this.trailPath,
    this.distance,
    this.duration,
    this.difficulty,
    this.ascent,
    this.isFerrata,
  });

  factory FavoriteTrail.fromTrail(
    Map<String, dynamic> trail, {
    String? distance,
    String? duration,
    int? difficulty,
    String? ascent,
    bool? isFerrata,
  }) {
    return FavoriteTrail(
      id: trail['id']?.toString() ?? '',
      name: trail['name']?.toString() ?? 'Trail',
      trailPath: _trailPathFromSubTrails(trail['subTrails']),
      distance: distance,
      duration: duration,
      difficulty: difficulty,
      ascent: ascent,
      isFerrata: isFerrata,
    );
  }

  Map<String, dynamic> toTrailMap() {
    return {
      'id': id,
      'name': name,
      'subTrails': trailPath
          .map(
            (segment) => segment
                .map((point) => LatLng(point.lat, point.lng))
                .toList(growable: false),
          )
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false),
    };
  }

  static List<List<TrailPoint>> _trailPathFromSubTrails(dynamic subTrails) {
    if (subTrails is! List) return const [];

    return subTrails
        .map<List<TrailPoint>>((segment) {
          if (segment is! List) return const [];

          return segment
              .map<TrailPoint?>((point) {
                if (point is TrailPoint) return point;
                if (point is LatLng) {
                  return TrailPoint(lat: point.latitude, lng: point.longitude);
                }
                if (point is Map) {
                  return TrailPoint.fromJson(
                    point.map((key, value) => MapEntry(key.toString(), value)),
                  );
                }
                return null;
              })
              .whereType<TrailPoint>()
              .toList(growable: false);
        })
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
  }
}
