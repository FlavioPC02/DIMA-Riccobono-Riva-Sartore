import 'dart:math' as math;

import 'package:flutter/material.dart';

class HikeProgressRing extends StatelessWidget {
  final double progress;
  final String label;
  final String? subtitle;
  final double strokeWidth;
  final Color? foregroundColor;
  final Color? backgroundColor;

  const HikeProgressRing({
    super.key,
    required this.progress,
    required this.label,
    this.subtitle,
    this.strokeWidth = 10,
    this.foregroundColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);

        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _HikeProgressRingPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              foregroundColor: foregroundColor ?? colorScheme.primary,
              backgroundColor:
                  backgroundColor ?? colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HikeProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color foregroundColor;
  final Color backgroundColor;

  const _HikeProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final baseRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(baseRect, -math.pi / 2, math.pi * 2, false, trackPaint);
    canvas.drawArc(
      baseRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HikeProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}