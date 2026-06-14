import 'package:hike_core/hike_core.dart';

class WatchLocationState {
  final HikeLiveStats stats;
  final HikeRecordingStatus status;

  //True while we are waiting for connection with phone
  final bool isConnecting;

  const WatchLocationState({
    required this.stats,
    required this.status,
    required this.isConnecting,
  });

  factory WatchLocationState.initial() => WatchLocationState(
    stats: HikeLiveStats.empty(), 
    status: HikeRecordingStatus.stopped, 
    isConnecting: true,
  );

  WatchLocationState copyWith ({
    HikeLiveStats? stats,
    HikeRecordingStatus? status,
    bool? isConnecting,
  }) =>
    WatchLocationState(
      stats: stats ?? this.stats, 
      status: status ?? this.status, 
      isConnecting: isConnecting ?? this.isConnecting,
    );
}