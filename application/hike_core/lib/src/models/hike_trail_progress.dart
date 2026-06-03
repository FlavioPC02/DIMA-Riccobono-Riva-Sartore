import 'package:equatable/equatable.dart';

import '../utils/hike_formatters.dart';

class HikeTrailProgress extends Equatable {
  final double travelledMeters;
  final double trailDistanceMeters;
  final double? bearingDegrees;

  const HikeTrailProgress({
    required this.travelledMeters,
    required this.trailDistanceMeters,
    this.bearingDegrees,
  });

  factory HikeTrailProgress.fromMap(Map<String, dynamic> map) {
    return HikeTrailProgress(
      travelledMeters: (map['travelledMeters'] as num).toDouble(),
      trailDistanceMeters: (map['trailDistanceMeters'] as num).toDouble(),
      bearingDegrees: (map['bearingDegrees'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'travelledMeters': travelledMeters,
    'trailDistanceMeters': trailDistanceMeters,
    'bearingDegrees': bearingDegrees,
  };

  double get progressFraction {
    if (trailDistanceMeters <= 0) return 0;
    final fraction = travelledMeters / trailDistanceMeters;
    return fraction.clamp(0.0, 1.0).toDouble();
  }

  String get travelledLabel => formatDistanceMeters(travelledMeters);

  String get trailDistanceLabel => formatDistanceMeters(trailDistanceMeters);

  String get progressLabel =>
      '${(progressFraction * 100).toStringAsFixed(0)}%';

  @override
  List<Object?> get props => [travelledMeters, trailDistanceMeters, bearingDegrees];
}