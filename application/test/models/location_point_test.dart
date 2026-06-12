import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:application/core/models/location_point.dart';

class FakeBinaryReader extends Fake implements BinaryReader {
  FakeBinaryReader(this.values);

  final List<dynamic> values;
  var index = 0;

  @override
  double readDouble() => values[index++] as double;

  @override
  int readInt() => values[index++] as int;
}

class FakeBinaryWriter extends Fake implements BinaryWriter {
  final List<dynamic> values = [];

  @override
  void writeDouble(double value) => values.add(value);

  @override
  void writeInt(int value) => values.add(value);
}

void main() {
  group('LocationPoint', () {
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final point = LocationPoint(
      lat: 45.0,
      lng: 9.0,
      altitude: 120.0,
      positionAccuracy: 1.2,
      altitudeAccuracy: 3.4,
      timestamp: timestamp,
    );

    test('toMap and fromMap roundtrip', () {
      final map = point.toMap();
      expect(map['lat'], 45.0);
      expect(map['lng'], 9.0);
      expect(map['timestamp'], timestamp.toIso8601String());

      final restored = LocationPoint.fromMap(map);
      expect(restored.lat, 45.0);
      expect(restored.lng, 9.0);
      expect(restored.altitude, 120.0);
      expect(restored.timestamp, timestamp);
    });

    test('LocationPointAdapter read/write serializes the same values', () {
      final adapter = LocationPointAdapter();
      final writer = FakeBinaryWriter();
      adapter.write(writer, point);

      expect(writer.values, <dynamic>[
        45.0,
        9.0,
        120.0,
        1.2,
        3.4,
        timestamp.millisecondsSinceEpoch,
      ]);

      final reader = FakeBinaryReader(writer.values);
      final restored = adapter.read(reader);
      expect(restored.lat, point.lat);
      expect(restored.lng, point.lng);
      expect(restored.altitude, point.altitude);
      expect(restored.positionAccuracy, point.positionAccuracy);
      expect(restored.altitudeAccuracy, point.altitudeAccuracy);
      expect(restored.timestamp.toUtc(), point.timestamp.toUtc());
    });
  });
}
