import 'package:equatable/equatable.dart';

class HikeLiveStats extends Equatable {
  final Duration elapsedTime;
  final double distanceMeters;
  final double totalDistanceMeters;
  final double? elevationGapMeters;
  final DateTime eta;

  const HikeLiveStats({
    required this.elapsedTime,
    required this.distanceMeters,
    required this.totalDistanceMeters,
    required this.elevationGapMeters,
    required this.eta,
  });

  factory HikeLiveStats.fromMap(Map<String, dynamic> map) {
    return HikeLiveStats(
      elapsedTime: Duration(milliseconds: (map['elapsedMs'] as num).round()),
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      totalDistanceMeters: (map['totalDistanceMeters'] as num).toDouble(),
      elevationGapMeters: (map['elevationGapMeters'] as num?)?.toDouble(),
      eta: DateTime.parse(map['eta'] as String),
    );
  }

  static HikeLiveStats empty() {
    return HikeLiveStats(
      elapsedTime: Duration.zero,
      distanceMeters: 0,
      totalDistanceMeters: 0,
      elevationGapMeters: 0,
      eta: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() =>
      {
        'elapsedMs': elapsedTime.inMilliseconds,
        'distanceMeters': distanceMeters,
        'totalDistanceMeters': totalDistanceMeters,
        'elevationGapMeters': elevationGapMeters,
        'eta': eta.toIso8601String(),
      };

  HikeLiveStats copyWith({
    Duration? elapsedTime,
    double? distanceMeters,
    double? totalDistanceMeters,
    double? elevationGapMeters,
    DateTime? eta,
  }) {
    return HikeLiveStats(
      elapsedTime: elapsedTime ?? this.elapsedTime,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      elevationGapMeters: elevationGapMeters ?? this.elevationGapMeters,
      eta: eta ?? this.eta,
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
      ];
}

extension MapNullableLookup on Map<String, dynamic>? {
  R? let<R>(R Function(Map<String, dynamic> map) convert) {
    final value = this;
    if (value == null) return null;
    return convert(value);
  }
}