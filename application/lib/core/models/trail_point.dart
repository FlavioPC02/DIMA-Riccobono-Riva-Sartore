class TrailPoint {
  final double lat;
  final double lng;

  const TrailPoint({required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory TrailPoint.fromJson(Map<String, dynamic> json) {
    return TrailPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}
