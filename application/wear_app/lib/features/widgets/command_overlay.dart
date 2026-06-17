import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/widgets/command_button.dart';

class CommandOverlay extends StatelessWidget{
  const CommandOverlay({
    super.key,
    required this.isRound,
    required this.onDismiss,
  });

  final bool isRound;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: GestureDetector(
            onTap: () {}, //Prevent accidental taps to dismiss
            child: BlocBuilder<WatchLocationCubit, WatchLocationState>(
                buildWhen: (p, c) => p.status != c.status,
                builder: (context, state) {
                  final cubit = context.read<WatchLocationCubit>();
                  final isPaused = state.isPaused;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CommandButton(
                          label: isPaused ? 'Resume': 'Pause',
                          icon: isPaused ? Icons.play_arrow : Icons.pause,
                          color: const Color(0xFF4CAF82),
                          onTap: () {
                            isPaused ? cubit.resume() : cubit.pause();
                            onDismiss();
                          }
                      ),
                      SizedBox(height: screenSize.height * 0.04),
                      CommandButton(
                          label: 'Stop', 
                          icon: Icons.stop, 
                          color: const Color(0xFFE57373),
                          onTap: () {
                            _showStopConfirmation(context, cubit);
                          }
                      ),
                    ],
                  );
                }
            ),
          )
        ),
      ),
    );
  }

  void _showStopConfirmation(BuildContext context, WatchLocationCubit cubit) {
    final screenSize = MediaQuery.of(context).size;
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A2E24),
          surfaceTintColor: Colors.transparent,
          insetPadding: EdgeInsets.all(screenSize.width * 0.05),
          titlePadding: EdgeInsets.only(
              top: screenSize.height * 0.1,
              bottom: screenSize.height * 0.05,
          ),
          actionsPadding: EdgeInsets.only(bottom: screenSize.height * 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(screenSize.width * 0.1)),
          title: Text(
            'Stop hike?',
            style: TextStyle(
                color: Colors.white,
                fontSize: (screenSize.width * 0.08).clamp(14.0, 18.0),
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: (screenSize.width * 0.06).clamp(11.0, 14.0),
                  ),
                ),
            ),
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  cubit.stop();
                  onDismiss();
                },
                child: Text(
                    'Stop',
                    style: TextStyle(
                        color: const Color(0xFFE57373),
                        fontWeight: FontWeight.bold,
                        fontSize: (screenSize.width * 0.06).clamp(11.0, 14.0),
                    )
                ),
            ),
          ],
        )
    );
  }
}