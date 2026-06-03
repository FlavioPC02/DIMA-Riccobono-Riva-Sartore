import 'package:equatable/equatable.dart';

class HikeOffTrailWarning extends Equatable {
  final int distanceMeters;
  final String direction;
  final DateTime triggeredAt;

  const HikeOffTrailWarning({
    required this.distanceMeters,
    required this.direction,
    required this.triggeredAt,
  });

  factory HikeOffTrailWarning.fromMap(Map<String, dynamic> map) {
    return HikeOffTrailWarning(
      distanceMeters: (map['distanceMeters'] as num).round(),
      direction: map['direction'] as String? ?? '',
      triggeredAt:
          DateTime.tryParse(map['triggeredAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'distanceMeters': distanceMeters,
    'direction': direction,
    'triggeredAt': triggeredAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [distanceMeters, direction, triggeredAt];
}