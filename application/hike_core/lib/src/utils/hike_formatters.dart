import 'package:intl/intl.dart';

String formatDistanceMeters(double meters) {
  if (meters == 0) return '0 m';
  if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

String formatElevationGapMeters(double? elevationGapMeters) {
  if (elevationGapMeters == null) return '--';
  final sign = elevationGapMeters >= 0 ? '+' : '-';
  return '$sign${elevationGapMeters.abs().toStringAsFixed(1)} m';
}

extension HikeDurationFormatting on Duration {
  String toCompactLabel({bool includeSeconds = true}) {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (hours > 0) {
      if (minutes == 0) return '${hours}h';
      return '${hours}h ${minutes}m';
    }

    if (minutes > 0) {
      if (!includeSeconds || seconds == 0) return '${minutes}m';
      return '${minutes}m ${seconds}s';
    }

    return includeSeconds ? '${seconds}s' : '0m';
  }
}

extension HikeMinuteDurationFormatting on int {
  String toMinuteDurationLabel() {
    return Duration(minutes: this).toCompactLabel(includeSeconds: false);
  }
}

extension HikeDateTimeFormatting on DateTime {
  String toCompactLabel() {
    return DateFormat('HH:mm').format(this);
  }
}