import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGeolocatorPlatform extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  bool locationServiceEnabled = true;
  LocationPermission permission = LocationPermission.always;
  bool shouldFailNextRequest = false;

  @override
  Future<bool> isLocationServiceEnabled() async => locationServiceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    return Position(
      longitude: 12.4924,
      latitude: 41.8902,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }

  @override
  Stream<ServiceStatus> getServiceStatusStream() {
    return Stream.value(ServiceStatus.enabled);
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    return Position(
      longitude: 12.4924,
      latitude: 41.8902,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return Stream.value(Position(
      longitude: 12.4924,
      latitude: 41.8902,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    ));
  }
}

class FakeHttpOverrides extends HttpOverrides {
  static bool shouldFailConnections = false;
  static bool returnEmptyNominatim = false;
  static bool returnEmptyOverpass = false;
  static bool returnServerError = false;
  
  @override
  HttpClient createHttpClient(SecurityContext? context) => FakeHttpClient();
}

class FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (FakeHttpOverrides.shouldFailConnections) {
      throw const SocketException('Connection failed');
    }
    return FakeHttpClientRequest(url);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (FakeHttpOverrides.shouldFailConnections) {
      throw const SocketException('Connection failed');
    }
    return FakeHttpClientRequest(url);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    if (FakeHttpOverrides.shouldFailConnections) {
      throw const SocketException('Connection failed');
    }
    return FakeHttpClientRequest(url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }

  @override
  void removeAll(String name) {
    _headers.remove(name);
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientRequest implements HttpClientRequest {
  final Uri url;
  FakeHttpClientRequest(this.url);

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;

  @override
  HttpHeaders get headers => FakeHttpHeaders();

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain();
  }

  @override
  Future<HttpClientResponse> close() async => FakeHttpClientResponse(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final Uri url;
  FakeHttpClientResponse(this.url);

  @override
  int get statusCode => FakeHttpOverrides.returnServerError ? 500 : 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  bool get persistentConnection => true;

  List<int> _getBody() {
    final urlString = url.toString();
    if (urlString.contains('nominatim')) {
      if (FakeHttpOverrides.returnEmptyNominatim) {
        return utf8.encode('[]');
      }
      return utf8.encode('[{"lat": "45.4642", "lon": "9.1900", "display_name": "Milano, Italia"}]');
    } else if (urlString.contains('overpass')) {
      if (FakeHttpOverrides.returnEmptyOverpass) {
        return utf8.encode('{"elements": []}');
      }
      return utf8.encode('''{
        "elements": [
          {
            "type": "relation",
            "id": 1,
            "tags": {
              "name": "Sentiero Facile",
              "distance": "4.5 km",
              "duration": "01:30",
              "cai_scale": "T",
              "ascent": "150",
              "website": "https://www.example.com"
            },
            "members": [
              {
                "type": "way",
                "geometry": [{"lat": 41.9, "lon": 12.5}, {"lat": 41.91, "lon": 12.51}]
              }
            ]
          },
          {
            "type": "relation",
            "id": 2,
            "tags": {
              "name": "Sentiero Difficile",
              "distance": "10.0 km",
              "sac_scale": "t4",
              "via_ferrata_scale": "B",
              "ascent": "1200",
              "duration": "01:30"
            },
            "members": [
              {
                "type": "way",
                "geometry": [{"lat": 45.9, "lon": 9.5}, {"lat": 45.91, "lon": 9.51}]
              }
            ]
          },
          {
            "type": "relation",
            "id": 3,
            "tags": {
              "name": "Sentiero Ascesa",
              "distance": "18.0 km",
              "ascent": "1800",
              "duration": "04:30"
            },
            "members": [
              {
                "type": "way",
                "geometry": [{"lat": 46.0, "lon": 10.0}, {"lat": 46.01, "lon": 10.01}]
              }
            ]
          }
        ]
      }''');
    } else {
      return transparentImage;
    }
  }

  @override
  int get contentLength => _getBody().length;

  static const List<int> transparentImage = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_getBody()).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> tearDownMap(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}