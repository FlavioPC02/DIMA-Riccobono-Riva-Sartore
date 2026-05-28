import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

class FakeHttpOverrides extends HttpOverrides {
  static bool shouldFailConnections = false;
  static bool emptyOverpassRelation = false;
  static bool emptyElevationData = false;
  static bool emptyWeatherForecast = false;

  @override
  HttpClient createHttpClient(SecurityContext? context) => FakeHttpClient();
}

class FakeHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _handleRequest(url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _handleRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _handleRequest(url);

  @override
  void close({bool force = false}) {
  }

  Future<HttpClientRequest> _handleRequest(Uri url) async {
    if (FakeHttpOverrides.shouldFailConnections) {
      throw const SocketException('Connection failed');
    }
    return FakeHttpClientRequest(url);
  }
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
  int get statusCode => 200;

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
      return utf8.encode('[{"lat": "45.4642", "lon": "9.1900", "display_name": "Milano, Italia"}]');
    } else if (urlString.contains('overpass')) {
      if (FakeHttpOverrides.emptyOverpassRelation) {
        return utf8.encode('{"elements": []}');
      }
      return utf8.encode('''{
        "elements": [
          {
            "type": "relation",
            "id": 12345,
            "tags": {
              "name": "Sentiero Test",
              "distance": "10 km",
              "ascent": "500",
              "operator": "Test Operator",
              "website": "www.example.com"
            }
          },
          {
            "type": "way",
            "tags": {"surface": "dirt", "incline": "10%"},
            "geometry": [{"lat": 45.4, "lon": 9.1}, {"lat": 45.5, "lon": 9.2}]
          }
        ]
      }''');
    } else if (urlString.contains('open-elevation.com')) {
      if (FakeHttpOverrides.emptyElevationData) {
        return utf8.encode('{"results": []}');
      }
      return utf8.encode('{"results": [{"elevation": 100.0}, {"elevation": 200.0}]}');
    } else if (urlString.contains('open-meteo')) {
      if (FakeHttpOverrides.emptyWeatherForecast) {
        return utf8.encode('''{
          "daily": {
            "time": [],
            "weather_code": [],
            "temperature_2m_max": [],
            "temperature_2m_min": []
          }
        }''');
      }
      return utf8.encode('''{
        "daily": {
          "time": [
            "2026-05-27",
            "2026-05-28",
            "2026-05-29"
          ],
          "weather_code": [
            0,
            61,
            3
          ],
          "temperature_2m_max": [
            24.5,
            18.0,
            20.5
          ],
          "temperature_2m_min": [
            15.0,
            12.0,
            14.0
          ]
        }
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
