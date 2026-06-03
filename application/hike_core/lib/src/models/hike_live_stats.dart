import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../utils/hike_formatters.dart';
import 'hike_off_trail_warning.dart';
import 'hike_recording_state.dart';
import 'hike_trail_progress.dart';

class HikeLiveStats extends Equatable {
  final Duration elapsedTime;
  final double distanceMeters;
  final double? elevationGapMeters;
  final DateTime eta;
  final HikeRecordingState recordingState;
  final HikeTrailProgress? trailProgress;
  final HikeOffTrailWarning? offTrailWarning;
  final LatLng? currentLocation;
  final LatLng? nextWaypoint;

  const HikeLiveStats({
    required this.elapsedTime,
    required this.distanceMeters,
    required this.elevationGapMeters,
    required this.eta,
    required this.recordingState,
    this.trailProgress,
    this.offTrailWarning,
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
      recordingState: HikeRecordingState.values.byName(
        map['recordingState'] as String? ?? HikeRecordingState.idle.name,
      ),
      trailProgress: (map['trailProgress'] as Map<String, dynamic>?)
          ?.let(HikeTrailProgress.fromMap),
      offTrailWarning: (map['offTrailWarning'] as Map<String, dynamic>?)
          ?.let(HikeOffTrailWarning.fromMap),
      currentLocation: _locationFromMap(currentLocationMap),
      nextWaypoint: _locationFromMap(nextWaypointMap),
    );
  }

  Map<String, dynamic> toMap() => {
    'elapsedSeconds': elapsedTime.inSeconds,
    'distanceMeters': distanceMeters,
    'elevationGapMeters': elevationGapMeters,
    'eta': eta.toIso8601String(),
    'recordingState': recordingState.name,
    'trailProgress': trailProgress?.toMap(),
    'offTrailWarning': offTrailWarning?.toMap(),
    'currentLocation': _locationToMap(currentLocation),
    'nextWaypoint': _locationToMap(nextWaypoint),
  };

  String get elapsedLabel => elapsedTime.toCompactLabel();

  String get distanceLabel => formatDistanceMeters(distanceMeters);

  String get elevationGapLabel => formatElevationGapMeters(elevationGapMeters);

  String get etaLabel => eta.toCompactLabel();

  bool get hasTrailProgress => trailProgress != null;

  bool get hasOffTrailWarning => offTrailWarning != null;

  HikeLiveStats copyWith({
    Duration? elapsedTime,
    double? distanceMeters,
    double? elevationGapMeters,
    DateTime? eta,
    HikeRecordingState? recordingState,
    HikeTrailProgress? trailProgress,
    HikeOffTrailWarning? offTrailWarning,
    LatLng? currentLocation,
    LatLng? nextWaypoint,
  }) {
    return HikeLiveStats(
      elapsedTime: elapsedTime ?? this.elapsedTime,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elevationGapMeters: elevationGapMeters ?? this.elevationGapMeters,
      eta: eta ?? this.eta,
      recordingState: recordingState ?? this.recordingState,
      trailProgress: trailProgress ?? this.trailProgress,
      offTrailWarning: offTrailWarning ?? this.offTrailWarning,
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
    recordingState,
    trailProgress,
    offTrailWarning,
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