class LocationPoint {
  
  final double lat;
  final double lng;
  final double altitude;
  //TODO: necessario salvare accuracy o posso evitare?
  final double positionAccuracy;
  final double altitudeAccuracy;
  final int timestamp;

  LocationPoint({
    required this.lat,
    required this.lng,
    required this.altitude,
    required this.positionAccuracy,
    required this.altitudeAccuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'altitude': altitude,
    'positionAccuracy': positionAccuracy,
    'altitudeAccuracy': altitudeAccuracy,
    'timestamp': timestamp,
  };

  static LocationPoint fromMap(Map data) {
    return LocationPoint(
      lat: data['lat'], 
      lng: data['lng'], 
      altitude: data['altitude'], 
      positionAccuracy: data['positionAccuracy'], 
      altitudeAccuracy: data['altitudeAccuracy'], 
      timestamp: data['timestamp'],
    );
  }
}