import 'package:flutter/material.dart';

import '../models/hike_trail_progress.dart';
import '../utils/hike_formatters.dart';
import 'hike_progress_ring.dart';

class HikeMetricScreen extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final HikeTrailProgress? trailProgress;
  final Widget? footer;

  const HikeMetricScreen({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.trailProgress,
    this.footer,
  });

  factory HikeMetricScreen.elapsed({
    required Duration elapsedTime,
    HikeTrailProgress? trailProgress,
    Widget? footer,
  }) {
    return HikeMetricScreen(
      title: 'Elapsed Time',
      value: elapsedTime.toCompactLabel(),
      subtitle: 'Current hike session',
      trailProgress: trailProgress,
      footer: footer,
    );
  }

  factory HikeMetricScreen.distance({
    required double distanceMeters,
    HikeTrailProgress? trailProgress,
    Widget? footer,
  }) {
    return HikeMetricScreen(
      title: 'Distance',
      value: formatDistanceMeters(distanceMeters),
      subtitle: 'Covered so far',
      trailProgress: trailProgress,
      footer: footer,
    );
  }

  factory HikeMetricScreen.elevationGap({
    required double? elevationGapMeters,
    HikeTrailProgress? trailProgress,
    Widget? footer,
  }) {
    return HikeMetricScreen(
      title: 'Elevation Gap',
      value: formatElevationGapMeters(elevationGapMeters),
      subtitle: 'Net altitude change',
      trailProgress: trailProgress,
      footer: footer,
    );
  }

  factory HikeMetricScreen.eta({
    required DateTime eta,
    HikeTrailProgress? trailProgress,
    Widget? footer,
  }) {
    return HikeMetricScreen(
      title: 'ETA',
      value: eta.toCompactLabel(),
      subtitle: 'Projected arrival',
      trailProgress: trailProgress,
      footer: footer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (trailProgress != null) ...[
            SizedBox(
              height: 120,
              child: HikeProgressRing(
                progress: trailProgress!.progressFraction,
                label: value,
                subtitle: subtitle,
              ),
            ),
          ] else ...[
            Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
          if (footer != null) ...[
            const SizedBox(height: 16),
            footer!,
          ],
        ],
      ),
    );
  }
}