import 'dart:math' as math;

import 'package:flutter/material.dart';

class CompassWidget extends StatelessWidget {
  const CompassWidget({
    super.key,
    required this.bearingDegrees,
  });

  final double bearingDegrees;

  @override
  Widget build(BuildContext context) {
    final needleRotation = (bearingDegrees - 90) * math.pi / 180;

    return SizedBox(
      height: 150,
      width: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.72),
                width: 8,
              ),
              gradient: const RadialGradient(
                colors: [Color(0xFF1F322A), Color(0xFF0E1714)],
              ),
            ),
          ),
          Transform.rotate(
            angle: needleRotation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.navigation_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ],
            ),
          ),
          Positioned(
            top: 14,
            child: Text(
              'N',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}