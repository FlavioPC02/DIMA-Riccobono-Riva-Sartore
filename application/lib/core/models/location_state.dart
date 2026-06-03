part of '../cubit/location_cubit.dart';

enum LocationStateKind {idle, tracking, error}

class LocationState extends Equatable {
  final LocationStateKind kind;
  final List<LocationPoint> points;
  final LocationPoint? current;
  final String? errorMessage;

  //distance in meters computed via the Haversine formula
  final double distance;

  //elevation gap in meters, null when fewer than two readings are available.
  final double? elevationGap;

  final double totalAscent;
  final double totalDescent;

  const LocationState._({
    required this.kind,
    this.points = const [],
    this.current,
    this.errorMessage,
    this.distance = 0,
    this.elevationGap,
    this.totalAscent = 0,
    this.totalDescent = 0,
  });

  const LocationState.idle()
    : this._(kind: LocationStateKind.idle);

  const LocationState.tracking({
    List<LocationPoint> points = const [],
    LocationPoint? current,
    double distance = 0,
    double? elevationGap,
    double totalAscent = 0,
    double totalDescent = 0,
  }) : this._(
    kind: LocationStateKind.tracking,
    points: points,
    current: current,
    distance: distance,
    elevationGap: elevationGap,
    totalAscent: totalAscent,
    totalDescent: totalDescent,
  );

  const LocationState.error(String message)
    : this._(kind: LocationStateKind.error, errorMessage: message);

  bool get isTracking => kind == LocationStateKind.tracking;
  bool get isError => kind == LocationStateKind.error;

  //UI formatters
  String getDistanceLabel() {
    if (!isTracking) return '--';
    return formatDistanceMeters(distance);
  }

  String getElevationGapLabel() {
    if (!isTracking) return '--';
    return formatElevationGapMeters(elevationGap);
  }

  String get totalAscentLabel => '+${totalAscent.toStringAsFixed(1)} m';
  String get totalDescentLabel => '+${totalDescent.toStringAsFixed(1)} m';

  @override
  List<Object?> get props => [
    kind, 
    points, 
    current, 
    errorMessage,
    distance,
    elevationGap,
    totalAscent,
    totalDescent,
  ];
}