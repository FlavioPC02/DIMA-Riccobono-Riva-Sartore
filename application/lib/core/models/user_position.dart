import 'package:latlong2/latlong.dart';

class UserPosition {
  final LatLng position;
  final double positionAccuracy;
  final double altitude;
  final double altitudeAccuracy;

  const UserPosition({
    required this.position,
    required this.positionAccuracy,
    required this.altitude,
    required this.altitudeAccuracy,
  });
}