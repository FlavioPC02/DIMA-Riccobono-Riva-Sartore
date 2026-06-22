import 'package:application/core/cubit/location_cubit.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:hike_core/hike_core.dart';

class StatsRecordingCard extends StatefulWidget {
  final String trailName;
  final Duration elapsedTime;
  final bool isRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback onStopRecording;
  final LocationState stats;

  const StatsRecordingCard({
    super.key,
    required this.trailName,
    required this.elapsedTime,
    required this.isRecording,
    required this.onToggleRecording,
    required this.onStopRecording,
    required this.stats,
  });

  static double collapsedSheetHeight(BuildContext context, String trailName) {
    final mediaQuery = MediaQuery.of(context);
    final textStyle = Theme.of(context).textTheme.titleMedium;
    final availableWidth = mediaQuery.size.width - 36;
    final textPainter = TextPainter(
      text: TextSpan(text: trailName, style: textStyle),
      textDirection: Directionality.of(context),
      textAlign: TextAlign.center,
      maxLines: null,
    )..layout(maxWidth: availableWidth);

    const double collapsedTopPadding = 16;
    const double collapsedBottomPadding = 16;
    return collapsedTopPadding + textPainter.height + collapsedBottomPadding;
  }

  @override
  State<StatsRecordingCard> createState() => _StatsRecordingCardState();
}

class _StatsRecordingCardState extends State<StatsRecordingCard> {
  static const double _minSheetSize = 0.14;
  static const double _maxSheetSize = 0.80;
  static const double _detailsRevealOffset = 0.08;

  double _sheetExtent = _minSheetSize;
  double _collapsedSheetSize = _minSheetSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final collapsedSheetSize = _calculateCollapsedSheetSize(
      context,
      widget.trailName,
    );
    if ((collapsedSheetSize - _collapsedSheetSize).abs() > 0.001) {
      _collapsedSheetSize = collapsedSheetSize;
      if (_sheetExtent < _collapsedSheetSize) {
        _sheetExtent = _collapsedSheetSize;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDetails =
        _sheetExtent >=
        math.min(_collapsedSheetSize + _detailsRevealOffset, _maxSheetSize);

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if ((notification.extent - _sheetExtent).abs() > 0.001) {
          setState(() {
            _sheetExtent = notification.extent;
          });
        }
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: _collapsedSheetSize,
        minChildSize: _collapsedSheetSize,
        maxChildSize: _maxSheetSize,
        expand: true,
        builder: (context, scrollController) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                  bottom: Radius.zero,
                ),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.25),
                ),
              ),
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                bottom: true,
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      showDetails ? 10 : 16,
                      18,
                      showDetails ? 14 : 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            key: const ValueKey('sheet_drag_handle'),
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSecondary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.trailName,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium!.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                        if (showDetails) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 10),
                          Column(
                            children: [
                              Text('Time', style: theme.textTheme.bodyMedium),
                              Text(
                                widget.elapsedTime.toCompactLabel(),
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: Column(
                              key: const ValueKey('expanded-stats'),
                              children: [
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 14),
                                Column(
                                  children: [
                                    Text(
                                      'ETA',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    Text(
                                      widget.stats.eta?.toCompactLabel() ?? '--',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                            'Distance',
                                            style: theme.textTheme.bodyMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            widget.stats.getDistanceLabel(),
                                            style: theme.textTheme.titleLarge,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 48,
                                      child: VerticalDivider(
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                            'Elevation Gap',
                                            style: theme.textTheme.bodyMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.stats.getElevationGapLabel(),
                                            style: theme.textTheme.titleLarge,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: widget.onToggleRecording,
                                        label: widget.isRecording
                                            ? const Text('Pause')
                                            : const Text('Resume'),
                                        icon: widget.isRecording
                                            ? const Icon(Icons.pause)
                                            : const Icon(Icons.play_arrow),
                                        style: widget.isRecording
                                            ? ElevatedButton.styleFrom(
                                                backgroundColor: AppColors
                                                    .pauseButtonBackground,
                                                foregroundColor: AppColors
                                                    .pauseButtonForeground,
                                              )
                                            : ElevatedButton.styleFrom(
                                                backgroundColor: AppColors
                                                    .resumeButtonBackground,
                                                foregroundColor: AppColors
                                                    .pauseButtonForeground,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: ElevatedButton.icon(
                                        key: const ValueKey('stop_button'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.stopButtonBackground,
                                          foregroundColor:
                                              AppColors.stopButtonForeground,
                                        ),
                                        onPressed: widget.onStopRecording,
                                        label: const Text('Stop'),
                                        icon: const Icon(Icons.stop),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static double _calculateCollapsedSheetHeight(
    BuildContext context,
    String trailName,
  ) {
    return StatsRecordingCard.collapsedSheetHeight(context, trailName);
  }

  double _calculateCollapsedSheetSize(BuildContext context, String trailName) {
    final mediaQuery = MediaQuery.of(context);
    final collapsedHeight = _calculateCollapsedSheetHeight(context, trailName);
    final collapsedSize =
        collapsedHeight / mediaQuery.size.height +
        mediaQuery.padding.bottom / mediaQuery.size.height;

    return collapsedSize.clamp(_minSheetSize, _maxSheetSize);
  }
}