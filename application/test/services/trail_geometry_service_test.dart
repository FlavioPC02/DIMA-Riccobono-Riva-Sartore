import 'dart:convert';

import 'package:application/services/trail_geometry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fetchTrailPath rebuilds trail segments from an OSM relation', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.body, contains('relation(12345)'));
      expect(request.headers['User-Agent'], 'FlutterHikingApp/1.0');

      return http.Response(
        jsonEncode({
          'elements': [
            {
              'type': 'way',
              'geometry': [
                {'lat': 45.1, 'lon': 9.1},
                {'lat': 45.2, 'lon': 9.2},
              ],
            },
            {
              'type': 'way',
              'geometry': [
                {'lat': 45.3, 'lon': 9.3},
              ],
            },
          ],
        }),
        200,
      );
    });
    final service = OverpassTrailGeometryService(
      client: client,
      endpoints: [Uri.parse('https://overpass.test/api')],
    );

    final trailPath = await service.fetchTrailPath('12345');

    expect(trailPath, hasLength(2));
    expect(trailPath.first, hasLength(2));
    expect(trailPath.first.first.latitude, 45.1);
    expect(trailPath.first.first.longitude, 9.1);
    expect(trailPath.last.single.latitude, 45.3);
  });

  test(
    'fetchTrailPath ignores invalid relation ids without a request',
    () async {
      var requested = false;
      final client = MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      });
      final service = OverpassTrailGeometryService(client: client);

      expect(await service.fetchTrailPath('not-an-id'), isEmpty);
      expect(requested, isFalse);
    },
  );

  test('falls back to second endpoint when first endpoint fails', () async {
    var calls = 0;

    final client = MockClient((request) async {
      calls++;

      if (calls == 1) {
        return http.Response('Server error', 500);
      }

      return http.Response(
        jsonEncode({
          'elements': [
            {
              'type': 'way',
              'geometry': [
                {'lat': 45.0, 'lon': 9.0},
              ],
            },
          ],
        }),
        200,
      );
    });

    final service = OverpassTrailGeometryService(
      client: client,
      endpoints: [
        Uri.parse('https://first.test'),
        Uri.parse('https://second.test'),
      ],
    );

    final result = await service.fetchTrailPath('123');

    expect(calls, 2);
    expect(result, hasLength(1));
  });

  test('throws TrailGeometryException if all endpoints fail', () async {
    final client = MockClient((_) async {
      return http.Response('failure', 500);
    });

    final service = OverpassTrailGeometryService(
      client: client,
      endpoints: [
        Uri.parse('https://first.test'),
        Uri.parse('https://second.test'),
      ],
    );

    expect(
      () => service.fetchTrailPath('123'),
      throwsA(isA<TrailGeometryException>()),
    );
  });

  test('falls back after network exception', () async {
    var calls = 0;

    final client = MockClient((_) async {
      calls++;

      if (calls == 1) {
        throw Exception('network error');
      }

      return http.Response(
        jsonEncode({
          'elements': [
            {
              'type': 'way',
              'geometry': [
                {'lat': 1.0, 'lon': 2.0},
              ],
            },
          ],
        }),
        200,
      );
    });

    final service = OverpassTrailGeometryService(
      client: client,
      endpoints: [
        Uri.parse('https://first.test'),
        Uri.parse('https://second.test'),
      ],
    );

    final result = await service.fetchTrailPath('99');

    expect(calls, 2);
    expect(result.single.single.latitude, 1);
  });
  
  test('TrailGeometryException contains message and cause', () async {
    final client = MockClient((_) async {
      throw Exception('boom');
    });

    final service = OverpassTrailGeometryService(
      client: client,
      endpoints: [Uri.parse('https://only.test')],
    );

    try {
      await service.fetchTrailPath('1');
      fail('Expected exception');
    } on TrailGeometryException catch (e) {
      expect(e.message, contains('Unable to retrieve trail'));
      expect(e.cause, isNotNull);
      expect(e.toString(), contains('Unable to retrieve trail'));
    }
  });
}
