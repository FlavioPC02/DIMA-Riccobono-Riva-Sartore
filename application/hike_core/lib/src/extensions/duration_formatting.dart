import 'package:intl/intl.dart';

extension DurationFormatting on Duration {
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

extension MinuteDurationFormatting on int {
  String toMinuteDurationLabel() {
    return Duration(minutes: this).toCompactLabel(includeSeconds: false);
  }
}

extension DateTimeFormatting on DateTime {
  String toCompactLabel() {
    return DateFormat('HH:mm').format(this);
  }
}
