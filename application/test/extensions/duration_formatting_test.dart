import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';

void main() {
  group('DurationFormatting', () {
    test('formats duration with hours and minutes', () {
      final duration = const Duration(hours: 2, minutes: 30, seconds: 12);
      expect(duration.toCompactLabel(), '2h 30m');
    });

    test('formats duration with minutes and seconds', () {
      final duration = const Duration(minutes: 5, seconds: 8);
      expect(duration.toCompactLabel(), '5m 8s');
    });

    test('formats duration with no seconds when requested', () {
      final duration = const Duration(minutes: 3, seconds: 12);
      expect(duration.toCompactLabel(includeSeconds: false), '3m');
    });

    test('formats short duration without seconds flag', () {
      final duration = const Duration(seconds: 7);
      expect(duration.toCompactLabel(includeSeconds: false), '0m');
    });
  });

  group('MinuteDurationFormatting', () {
    test('converts minutes to a minute-only duration label', () {
      expect(5.toMinuteDurationLabel(), '5m');
    });
  });

  group('DateTimeFormatting', () {
    test('formats time using HH:mm', () {
      final dateTime = DateTime(2024, 1, 2, 7, 5);
      expect(dateTime.toCompactLabel(), '07:05');
    });
  });
}
