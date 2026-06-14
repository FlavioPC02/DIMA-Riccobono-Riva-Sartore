import 'package:flutter/material.dart';

class ControlsOverlay extends StatelessWidget {
  const ControlsOverlay({
    super.key,
    required this.visible,
    required this.paused,
    required this.onDismiss,
    required this.onTogglePause,
    required this.onStop,
  });

  final bool visible;
  final bool paused;
  final VoidCallback onDismiss;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Container(
              color: Colors.black.withValues(alpha: 0.72),
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121C18),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.72),
                            ),
                            child: Icon(
                              Icons.radio_button_checked_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Controls',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        key: const Key('pause-button'),
                        onPressed: onTogglePause,
                        child: Text(paused ? 'Resume' : 'Pause'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonal(
                        key: const Key('stop-button'),
                        onPressed: onStop,
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}