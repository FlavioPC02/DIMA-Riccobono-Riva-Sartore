import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hike_core/hike_core.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/widgets/dim_label.dart';
import 'package:wear_app/features/widgets/screen_shell.dart';

class DistanceScreen extends StatelessWidget{
  const DistanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final ringSize = (screenSize.width * 0.28).clamp(45.0, 80.0);

    return BlocBuilder<WatchLocationCubit, WatchLocationState>(
        buildWhen: (p, c) => p.stats.distanceMeters != c.stats.distanceMeters,
        builder: (context, state) {
          final distM = state.stats.distanceMeters;
          final totalM = state.stats.totalDistanceMeters;
          final progress = (totalM > 0) ? (distM / totalM).clamp(0.0, 1.0) : 0.0;
          final distLabel = distM >= 1000
            ? '${(distM / 1000).toStringAsFixed(2)} km'
            : '${distM.toStringAsFixed(0)} m';
          final totalLabel = totalM >= 1000
            ? '${(totalM / 1000).toStringAsFixed(2)} km'
            : '${totalM.toStringAsFixed(0)} m';

          return ScreenShell(
              icon: Icons.route_outlined,
              label: 'Distance',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(ringSize, ringSize),
                          painter: _RingPainter(
                              progress: progress,
                              strokeWidth: ringSize * 0.1,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: ringSize * 0.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.02),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      distLabel,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: (screenSize.width * 0.1).clamp(14.0, 22.0),
                          fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const DimLabel('covered'),
                  SizedBox(height: screenSize.height * 0.005),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'of $totalLabel',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: (screenSize.width * 0.045).clamp(8.0, 11.0),
                      ),
                    ),
                  )
                ],
              )
          );
        }
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.strokeWidth});
  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = AppTheme.darkColorScheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}