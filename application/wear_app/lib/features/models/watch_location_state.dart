import 'package:hike_core/hike_core.dart';

class WatchLocationState {
  final HikeLiveStats stats;
  final HikeRecordingStatus status;

  //True while we are waiting for connection with phone
  final bool isConnecting;

  //The local time when stats were last received
  final DateTime? _lastUpdate;
  DateTime get lastUpdate => _lastUpdate ?? DateTime.now();

  bool get isPaused => status == HikeRecordingStatus.paused;
  bool get isRecording => status == HikeRecordingStatus.recording;

  const WatchLocationState({
    required this.stats,
    required this.status,
    required this.isConnecting,
    DateTime? lastUpdate,
  }) : _lastUpdate = lastUpdate;

  factory WatchLocationState.initial() => WatchLocationState(
    stats: HikeLiveStats.empty(), 
    status: HikeRecordingStatus.stopped, 
    isConnecting: true,
    lastUpdate: DateTime.now(),
  );

  WatchLocationState copyWith ({
    HikeLiveStats? stats,
    HikeRecordingStatus? status,
    bool? isConnecting,
    DateTime? lastUpdate,
  }) =>
    WatchLocationState(
      stats: stats ?? this.stats, 
      status: status ?? this.status, 
      isConnecting: isConnecting ?? this.isConnecting,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
}