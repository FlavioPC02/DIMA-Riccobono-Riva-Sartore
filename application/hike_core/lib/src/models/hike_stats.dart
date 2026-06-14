import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class HikeLiveStats extends Equatable {
  final Duration elapsedTime;
  final double distanceMeters;
  final double? elevationGapMeters;
  final DateTime eta;
  final LatLng? currentLocation;
  final LatLng? nextWaypoint;

  const HikeLiveStats({
    required this.elapsedTime,
    required this.distanceMeters,
    required this.elevationGapMeters,
    required this.eta,
    this.currentLocation,
    this.nextWaypoint,
  });

  factory HikeLiveStats.fromMap(Map<String, dynamic> map) {
    final currentLocationMap = map['currentLocation'] as Map<String, dynamic>?;
    final nextWaypointMap = map['nextWaypoint'] as Map<String, dynamic>?;

    return HikeLiveStats(
      elapsedTime: Duration(seconds: (map['elapsedSeconds'] as num).round()),
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      elevationGapMeters: (map['elevationGapMeters'] as num?)?.toDouble(),
      eta: DateTime.parse(map['eta'] as String),
      currentLocation: _locationFromMap(currentLocationMap),
      nextWaypoint: _locationFromMap(nextWaypointMap),
    );
  }

  static HikeLiveStats empty() {
    return HikeLiveStats(
      elapsedTime: Duration.zero, 
      distanceMeters: 0, 
      elevationGapMeters: 0, 
      eta: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'elapsedSeconds': elapsedTime.inSeconds,
    'distanceMeters': distanceMeters,
    'elevationGapMeters': elevationGapMeters,
    'eta': eta.toIso8601String(),
    'currentLocation': _locationToMap(currentLocation),
    'nextWaypoint': _locationToMap(nextWaypoint),
  };

//  String get elapsedLabel => elapsedTime.toCompactLabel();
//
//  String get distanceLabel => formatDistanceMeters(distanceMeters);
//
//  String get elevationGapLabel => formatElevationGapMeters(elevationGapMeters);
//
//  String get etaLabel => eta.toCompactLabel();

  HikeLiveStats copyWith({
    Duration? elapsedTime,
    double? distanceMeters,
    double? elevationGapMeters,
    DateTime? eta,
    LatLng? currentLocation,
    LatLng? nextWaypoint,
  }) {
    return HikeLiveStats(
      elapsedTime: elapsedTime ?? this.elapsedTime,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elevationGapMeters: elevationGapMeters ?? this.elevationGapMeters,
      eta: eta ?? this.eta,
      currentLocation: currentLocation ?? this.currentLocation,
      nextWaypoint: nextWaypoint ?? this.nextWaypoint,
    );
  }

  @override
  List<Object?> get props => [
    elapsedTime,
    distanceMeters,
    elevationGapMeters,
    eta,
    currentLocation,
    nextWaypoint,
  ];

  static LatLng? _locationFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return LatLng(
      (map['lat'] as num).toDouble(),
      (map['lng'] as num).toDouble(),
    );
  }

  static Map<String, dynamic>? _locationToMap(LatLng? location) {
    if (location == null) return null;
    return {
      'lat': location.latitude,
      'lng': location.longitude,
    };
  }
}

extension MapNullableLookup on Map<String, dynamic>? {
  R? let<R>(R Function(Map<String, dynamic> map) convert) {
    final value = this;
    if (value == null) return null;
    return convert(value);
  }
}