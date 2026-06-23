import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

abstract interface class TrailGeometryDataSource {
  Future<List<List<LatLng>>> fetchTrailPath(String trailId);
}

class OverpassTrailGeometryService implements TrailGeometryDataSource {
  static final List<Uri> _defaultEndpoints = [
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://overpass.private.coffee/api/interpreter'),
    Uri.parse('https://overpass.kumi.systems/api/interpreter'),
  ];

  final http.Client _client;
  final List<Uri> _endpoints;
  final Duration _timeout;

  OverpassTrailGeometryService({
    http.Client? client,
    List<Uri>? endpoints,
    Duration timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _endpoints = endpoints ?? _defaultEndpoints,
       _timeout = timeout;

  @override
  Future<List<List<LatLng>>> fetchTrailPath(String trailId) async {
    final relationId = int.tryParse(trailId);
    if (relationId == null || relationId <= 0) {
      _log('Invalid trailId: $trailId');
      return const [];
    }

    _log('Starting download for trailId=$trailId');

    final query =
        '''
[out:json][timeout:15];
relation($relationId);
way(r);
out geom;
''';

    Object? lastError;

    for (final endpoint in _endpoints) {
      try {
        _log('Trying ${endpoint.host}');
        final response = await _client
            .post(
              endpoint,
              body: query,
              headers: const {'User-Agent': 'FlutterHikingApp/1.0'},
            )
            .timeout(_timeout);

        if (response.statusCode != 200) {
          lastError = 'Overpass returned HTTP ${response.statusCode}';
          _log('${endpoint.host} returned HTTP ${response.statusCode}');
          continue;
        }

        final trailPath = _decodeTrailPath(response.body);
        final pointCount = trailPath.fold<int>(
          0,
          (total, segment) => total + segment.length,
        );
        _log(
          'Download completed: ${trailPath.length} segments, '
          '$pointCount points',
        );
        return trailPath;
      } catch (error) {
        lastError = error;
        _log('${endpoint.host} failed: $error');
      }
    }

    _log('Download failed for trailId=$trailId: $lastError');
    throw TrailGeometryException(
      'Unable to retrieve trail $trailId from Overpass',
      cause: lastError,
    );
  }

  List<List<LatLng>> _decodeTrailPath(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) return const [];

    final elements = decoded['elements'];
    if (elements is! List) return const [];

    final segments = <List<LatLng>>[];

    for (final element in elements.whereType<Map>()) {
      if (element['type'] != 'way') continue;

      final geometry = element['geometry'];
      if (geometry is! List) continue;

      final points = <LatLng>[];
      for (final coordinate in geometry.whereType<Map>()) {
        final lat = coordinate['lat'];
        final lng = coordinate['lon'];
        if (lat is! num || lng is! num) continue;

        points.add(LatLng(lat.toDouble(), lng.toDouble()));
      }

      if (points.isNotEmpty) segments.add(points);
    }

    return segments;
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[TrailDownload] $message');
  }
}

class TrailGeometryException implements Exception {
  final String message;
  final Object? cause;

  const TrailGeometryException(this.message, {this.cause});

  @override
  String toString() => cause == null ? message : '$message: $cause';
}
