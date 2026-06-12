import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:application/services/weather_service.dart';

class MockGeolocatorPlatform extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  LocationPermission permissionToCheck = LocationPermission.always;
  LocationPermission permissionToRequest = LocationPermission.always;

  @override
  Future<LocationPermission> checkPermission() async => permissionToCheck;

  @override
  Future<LocationPermission> requestPermission() async => permissionToRequest;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    return Position(
      longitude: 12.4924,
      latitude: 41.8902,
      timestamp: DateTime.now(),
      accuracy: 100.0,
      altitude: 10.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
}

void main() {
  late MockGeolocatorPlatform mockGeolocator;

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
  });

  group('WeatherService - Core and HTTP', () {
    final mockJsonResponse = {
      "daily": {
        "time": ["2026-06-12"],
        "weather_code": [3],
        "temperature_2m_max": [25.5],
        "temperature_2m_min": [15.0],
        "precipitation_probability_max": [40],
        "wind_speed_10m_max": [12.5]
      },
      "hourly": {
        "time": ["2026-06-12T08:00", "2026-06-12T09:00"],
        "weather_code": [1, 2],
        "temperature_2m": [20.0, 22.0],
        "precipitation_probability": [0, 10]
      }
    };

    test('fetchWeather should return data correctly', () async {
      final mockClient = MockClient((request) async => http.Response(jsonEncode(mockJsonResponse), 200));
      final service = WeatherService(client: mockClient);

      final result = await service.fetchWeather(DateTime(2026, 6, 12));

      expect(result.maxTemp, 25.5);
      expect(result.hourly.length, 2);
    });

    test('fetchWeather throws exception if date does not exist in JSON', () async {
      final mockClient = MockClient((request) async => http.Response(jsonEncode(mockJsonResponse), 200));
      final service = WeatherService(client: mockClient);

      expect(
        () => service.fetchWeather(DateTime(2026, 6, 15)),
        throwsA(isA<Exception>()),
      );
    });

    test('fetchMultipleDaysForecast throws exception on HTTP 500', () async {
      final mockClient = MockClient((request) async => http.Response('Server Error', 500));
      final service = WeatherService(client: mockClient);

      expect(
        () => service.fetchMultipleDaysForecast(41.8, 12.4),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('HTTP 500'))),
      );
    });
  });

  group('WeatherService - Geolocator Permissions', () {
    test('Requests permissions if checkPermission is denied but requestPermission succeeds', () async {
      mockGeolocator.permissionToCheck = LocationPermission.denied;
      mockGeolocator.permissionToRequest = LocationPermission.always;
      
      final mockClient = MockClient((request) async => http.Response('{"daily": {"time": ["2026-06-12"], "weather_code": [0], "temperature_2m_max": [0], "temperature_2m_min": [0], "precipitation_probability_max": [0], "wind_speed_10m_max": [0]}, "hourly": {"time": [], "weather_code": [], "temperature_2m": [], "precipitation_probability": []}}', 200));
      final service = WeatherService(client: mockClient);

      await service.fetchWeather(DateTime(2026, 6, 12));
    });

    test('Throws exception if permissions are deniedForever', () async {
      mockGeolocator.permissionToCheck = LocationPermission.deniedForever;
      
      final service = WeatherService();
      expect(
        () => service.fetchWeather(DateTime.now()),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('denied'))),
      );
    });
  });

  group('WeatherService - WMO Coverage (Internal Switch and Ifs)', () {
    test('Correctly maps all WMO code branches', () async {
      final wmoCodesToTest = [0, 1, 2, 3, 45, 51, 56, 61, 66, 71, 77, 80, 85, 95, 96, 999];
      
      final times = List.generate(wmoCodesToTest.length, (i) => "2026-06-${(i + 1).toString().padLeft(2, '0')}");
      final mockJsonResponse = {
        "daily": {
          "time": times,
          "weather_code": wmoCodesToTest,
          "temperature_2m_max": List.filled(wmoCodesToTest.length, 20.0),
          "temperature_2m_min": List.filled(wmoCodesToTest.length, 10.0),
        }
      };

      final mockClient = MockClient((request) async => http.Response(jsonEncode(mockJsonResponse), 200));
      final service = WeatherService(client: mockClient);

      final result = await service.fetchMultipleDaysForecast(41.0, 12.0);

      expect(result.length, wmoCodesToTest.length);
      
      expect(result[0]['desc'], 'Clear sky');
      expect(result[4]['desc'], 'Fog');
      expect(result.last['desc'], 'Unknown');
    });
  });
}