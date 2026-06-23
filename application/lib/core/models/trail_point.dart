class TrailPoint{
  final double lat;
  final double lng;

  const TrailPoint({
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }

  static TrailPoint fromMap(Map<dynamic, dynamic> map) {
    return TrailPoint(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
    );
  }
}