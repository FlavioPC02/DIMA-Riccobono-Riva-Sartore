import 'package:equatable/equatable.dart';

class HikeLiveStats extends Equatable {
  final Duration elapsedTime;
  final double distanceMeters;
  final double totalDistanceMeters;
  final double? elevationGapMeters;
  final DateTime eta;
  final bool isOffTrail;
  final String? offTrailDirection;

  const HikeLiveStats({
    required this.elapsedTime,
    required this.distanceMeters,
    this.totalDistanceMeters = 0.0,
    required this.elevationGapMeters,
    required this.eta,
    this.isOffTrail = false,
    this.offTrailDirection,
  });

  factory HikeLiveStats.fromMap(Map<String, dynamic> map) {
    return HikeLiveStats(
      elapsedTime: Duration(milliseconds: (map['elapsedMs'] as num).round()),
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      totalDistanceMeters: (map['totalDistanceMeters'] as num ?? 0.0).toDouble(),
      elevationGapMeters: (map['elevationGapMeters'] as num?)?.toDouble(),
      eta: DateTime.parse(map['eta'] as String),
      isOffTrail: map['isOffTrail'] as bool? ?? false,
      offTrailDirection: map['offTrailDirection'] as String?,
    );
  }

  static HikeLiveStats empty() {
    return HikeLiveStats(
      elapsedTime: Duration.zero,
      distanceMeters: 0,
      totalDistanceMeters: 0,
      elevationGapMeters: 0,
      eta: DateTime.now(),
      isOffTrail: false,
    );
  }

  Map<String, dynamic> toMap() =>
      {
        'elapsedMs': elapsedTime.inMilliseconds,
        'distanceMeters': distanceMeters,
        'totalDistanceMeters': totalDistanceMeters,
        'elevationGapMeters': elevationGapMeters,
        'eta': eta.toIso8601String(),
        'isOffTrail': isOffTrail,
        'offTrailDirection': offTrailDirection,
      };

  HikeLiveStats copyWith({
    Duration? elapsedTime,
    double? distanceMeters,
    double? totalDistanceMeters,
    double? elevationGapMeters,
    DateTime? eta,
    bool? isOffTrail,
    String? offTrailDirection,
  }) {
    return HikeLiveStats(
      elapsedTime: elapsedTime ?? this.elapsedTime,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      elevationGapMeters: elevationGapMeters ?? this.elevationGapMeters,
      eta: eta ?? this.eta,
      isOffTrail: isOffTrail ?? this.isOffTrail,
      offTrailDirection: offTrailDirection ?? this.offTrailDirection,
    );
  }

  @override
  List<Object?> get props =>
      [
        elapsedTime,
        distanceMeters,
        totalDistanceMeters,
        elevationGapMeters,
        eta,
        isOffTrail,
        offTrailDirection,
      ];
}

extension MapNullableLookup on Map<String, dynamic>? {
  R? let<R>(R Function(Map<String, dynamic> map) convert) {
    final value = this;
    if (value == null) return null;
    return convert(value);
  }
}