part of '../cubit/location_cubit.dart';

enum LocationStateKind {idle, tracking, paused, error}

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

  final DateTime? eta;

  final bool isOffTrail;
  final String? offTrailDirection;

  const LocationState._({
    required this.kind,
    this.points = const [],
    this.current,
    this.errorMessage,
    this.distance = 0,
    this.elevationGap,
    this.totalAscent = 0,
    this.totalDescent = 0,
    this.eta,
    this.isOffTrail = false,
    this.offTrailDirection,
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
    DateTime? eta,
    bool isOffTrail = false,
    String? offTrailDirection,
  }) : this._(
    kind: LocationStateKind.tracking,
    points: points,
    current: current,
    distance: distance,
    elevationGap: elevationGap,
    totalAscent: totalAscent,
    totalDescent: totalDescent,
    eta: eta,
    isOffTrail: isOffTrail,
    offTrailDirection: offTrailDirection,
  );

  const LocationState.paused({
    List<LocationPoint> points = const [],
    LocationPoint? current,
    double distance = 0,
    double? elevationGap,
    double totalAscent = 0,
    double totalDescent = 0,
    DateTime? eta,
    bool isOffTrail = false,
    String? offTrailDirection,
  }) : this._(
    kind: LocationStateKind.paused,
    points: points,
    current: current,
    distance: distance,
    elevationGap: elevationGap,
    totalAscent: totalAscent,
    totalDescent: totalDescent,
    eta: eta,
    isOffTrail: isOffTrail,
    offTrailDirection: offTrailDirection,
  );

  const LocationState.error(String message)
    : this._(kind: LocationStateKind.error, errorMessage: message);

  bool get isTracking => kind == LocationStateKind.tracking;
  bool get isPaused => kind == LocationStateKind.paused;
  bool get isActive => isTracking || isPaused;
  bool get isError => kind == LocationStateKind.error;

  //UI formatters
  String getDistanceLabel() {
    if (!isActive) return '--';
    if (distance == 0) return '0 m';
    if (distance < 1000) return '${distance.toStringAsFixed(0)} m';
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  String getElevationGapLabel() {
    if (!isActive) return '--';
    if (elevationGap == null) return '--';
    final sign = elevationGap! >= 0 ? '+' : '-';

    return '$sign${elevationGap!.toStringAsFixed(1)} m';
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
    eta,
    isOffTrail,
    offTrailDirection,
  ];
}