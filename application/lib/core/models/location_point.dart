import 'package:hive_ce_flutter/adapters.dart';

class LocationPoint {
  
  final double lat;
  final double lng;
  final double altitude;
  final double positionAccuracy;
  final double altitudeAccuracy;
  final DateTime timestamp;

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
    'timestamp': timestamp.toIso8601String(),
  };

  static LocationPoint fromMap(Map data) {
    return LocationPoint(
      lat: data['lat'], 
      lng: data['lng'], 
      altitude: data['altitude'], 
      positionAccuracy: data['positionAccuracy'], 
      altitudeAccuracy: data['altitudeAccuracy'], 
      timestamp: DateTime.parse(data['timestamp'] as String),
    );
  }
}

class LocationPointAdapter extends TypeAdapter<LocationPoint> {
  @override
  final int typeId = 1;

  @override
  LocationPoint read(BinaryReader reader) {
    return LocationPoint(
      lat: reader.readDouble(),
      lng: reader.readDouble(),
      altitude: reader.readDouble(),
      positionAccuracy: reader.readDouble(),
      altitudeAccuracy: reader.readDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, LocationPoint obj) {
    writer
      ..writeDouble(obj.lat)
      ..writeDouble(obj.lng)
      ..writeDouble(obj.altitude)
      ..writeDouble(obj.positionAccuracy)
      ..writeDouble(obj.altitudeAccuracy)
      ..writeInt(obj.timestamp.millisecondsSinceEpoch);
  }
}