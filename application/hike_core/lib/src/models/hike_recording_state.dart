enum HikeRecordingState { idle, recording, paused }

enum HikeRecordingAction { start, pause, stop }

extension HikeRecordingStateX on HikeRecordingState {
  bool get isActive => this != HikeRecordingState.idle;

  bool get isRecording => this == HikeRecordingState.recording;

  bool get isPaused => this == HikeRecordingState.paused;
}