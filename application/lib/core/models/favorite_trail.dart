import 'package:latlong2/latlong.dart';

class FavoriteTrail {
  final String id;
  final String name;

  final String? distance;
  final String? duration;
  final int? difficulty;
  final String? ascent;
  final bool? isFerrata;

  const FavoriteTrail({
    required this.id,
    required this.name,
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
      distance: distance,
      duration: duration,
      difficulty: difficulty,
      ascent: ascent,
      isFerrata: isFerrata,
    );
  }

  factory FavoriteTrail.fromJson(String id, Map<String, dynamic> json) {
    return FavoriteTrail(
      id: json['id']?.toString() ?? id,
      name: json['name']?.toString() ?? 'Trail',
      distance: json['distance']?.toString(),
      duration: json['duration']?.toString(),
      difficulty: json['difficulty'] as int?,
      ascent: json['ascent']?.toString(),
      isFerrata: json['isFerrata'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'distance': distance,
      'duration': duration,
      'difficulty': difficulty,
      'ascent': ascent,
      'isFerrata': isFerrata,
    };
  }

  Map<String, dynamic> toTrailMap() {
    return {'id': id, 'name': name, 'subTrails': const <List<LatLng>>[]};
  }
}
