import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:application/services/helpers/map_management_service_helper.dart';

class MockGeolocatorPlatform extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  bool locationServiceEnabled = true;
  LocationPermission permission = LocationPermission.always;

  @override
  Future<bool> isLocationServiceEnabled() async => locationServiceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    return Position(
      latitude: 41.8902,
      longitude: 12.4924,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
}

void main() {
  late GeolocatorPlatform originalPlatform;

  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
  });

  testWidgets('showLocationPermissionDialog renders required title and buttons', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () {
          showLocationPermissionDialog(context);
        },
        child: const Text('open'),
      );
    })));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Location permission required'), findsOneWidget);
    expect(find.text('Enable location permission'), findsOneWidget);
    expect(find.text('Ignore'), findsOneWidget);
  });

  testWidgets('showLocationServiceDialog renders required title and buttons', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () {
          showLocationServiceDialog(context);
        },
        child: const Text('open'),
      );
    })));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Location service required'), findsOneWidget);
    expect(find.text('Enable location permission'), findsOneWidget);
    expect(find.text('Ignore'), findsOneWidget);
  });

  testWidgets('checkInitialLocation returns default map center when service disabled', (tester) async {
    final mockGeolocator = MockGeolocatorPlatform();
    mockGeolocator.locationServiceEnabled = false;
    GeolocatorPlatform.instance = mockGeolocator;

    final controller = MapController();
    late Future<LatLng> resultFuture;

    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () {
          resultFuture = checkInitialLocation(context, controller);
        },
        child: const Text('open'),
      );
    })));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Location service required'), findsOneWidget);
    expect(await resultFuture, defaultMapCenter);
  });

  testWidgets('centerMapOnUser returns current center when permission is denied', (tester) async {
    final mockGeolocator = MockGeolocatorPlatform();
    mockGeolocator.locationServiceEnabled = true;
    mockGeolocator.permission = LocationPermission.denied;
    GeolocatorPlatform.instance = mockGeolocator;

    final controller = MapController();
    final currentCenter = const LatLng(41.9, 12.5);
    late Future<LatLng> resultFuture;

    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () {
          resultFuture = centerMapOnUser(context, currentCenter, controller);
        },
        child: const Text('open'),
      );
    })));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Location permission required'), findsOneWidget);
    expect(await resultFuture, currentCenter);
  });
}
