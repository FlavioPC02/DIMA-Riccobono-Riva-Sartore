import 'package:flutter/material.dart';

import '../models/hike_recording_state.dart';

class HikeRecordingControls extends StatelessWidget {
  final HikeRecordingState state;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const HikeRecordingControls({
    super.key,
    required this.state,
    required this.onStart,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryActionLabel = switch (state) {
      HikeRecordingState.recording => 'Pause',
      HikeRecordingState.paused => 'Resume',
      HikeRecordingState.idle => 'Start',
    };
    final primaryActionIcon = switch (state) {
      HikeRecordingState.recording => Icons.pause,
      HikeRecordingState.paused => Icons.play_arrow,
      HikeRecordingState.idle => Icons.play_arrow,
    };
    final primaryAction = state.isRecording ? onPause : onStart;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: primaryAction,
            icon: Icon(primaryActionIcon),
            label: Text(primaryActionLabel),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: state.isActive ? onStop : null,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}