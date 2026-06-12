import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:application/services/map_management_service.dart';
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

class FakeMapController extends Fake implements MapController {
  LatLng? movedCenter;
  double? movedZoom;

  @override
  bool move(LatLng center, double zoom, {Offset offset = Offset.zero, String? id}) {
    movedCenter = center;
    movedZoom = zoom;
    return true;
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

  testWidgets('moveCameraTo returns the new center after the map is rendered', (tester) async {
    final controller = FakeMapController();
    final center = moveCameraTo(10.0, 20.0, 8.0, controller);

    expect(center.latitude, 10.0);
    expect(center.longitude, 20.0);
  });

  testWidgets('checkInitialLocation shows service dialog when location services are disabled', (tester) async {
    final mockGeolocator = MockGeolocatorPlatform();
    mockGeolocator.locationServiceEnabled = false;
    GeolocatorPlatform.instance = mockGeolocator;
    final controller = FakeMapController();
    late Future<LatLng> resultFuture;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            resultFuture = checkInitialLocation(context, controller);
          },
          child: const Text('start'),
        ),
      ),
    ));

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.text('Location service required'), findsOneWidget);
    expect(await resultFuture, defaultMapCenter);
  });

  testWidgets('checkInitialLocation shows permission dialog when permission is denied', (tester) async {
    final mockGeolocator = MockGeolocatorPlatform();
    mockGeolocator.locationServiceEnabled = true;
    mockGeolocator.permission = LocationPermission.denied;
    GeolocatorPlatform.instance = mockGeolocator;
    final controller = FakeMapController();
    late Future<LatLng> resultFuture;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            resultFuture = checkInitialLocation(context, controller);
          },
          child: const Text('start'),
        ),
      ),
    ));

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.text('Location permission required'), findsOneWidget);
    expect(await resultFuture, defaultMapCenter);
  });

  testWidgets('centerMapOnUser returns current center when permission denied', (tester) async {
    final mockGeolocator = MockGeolocatorPlatform();
    mockGeolocator.locationServiceEnabled = true;
    mockGeolocator.permission = LocationPermission.deniedForever;
    GeolocatorPlatform.instance = mockGeolocator;
    final controller = FakeMapController();
    final currentCenter = const LatLng(41.9, 12.5);
    late Future<LatLng> resultFuture;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            resultFuture = centerMapOnUser(context, currentCenter, controller, zoom: 12);
          },
          child: const Text('start'),
        ),
      ),
    ));

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.text('Location permission required'), findsOneWidget);
    expect(await resultFuture, currentCenter);
  });

  testWidgets('checkInitialLocation returns current location when service enabled and permission granted', (tester) async {
    final mockGeolocator = MockGeolocatorPlatform();
    mockGeolocator.locationServiceEnabled = true;
    mockGeolocator.permission = LocationPermission.always;
    GeolocatorPlatform.instance = mockGeolocator;
    final controller = FakeMapController();
    late Future<LatLng> resultFuture;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            resultFuture = checkInitialLocation(context, controller);
          },
          child: const Text('start'),
        ),
      ),
    ));

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result.latitude, 41.8902);
    expect(result.longitude, 12.4924);
  });

  testWidgets('centerMapOnUser returns user location when permission granted', (tester) async {
    final mockGeolocator = MockGeolocatorPlatform();
    mockGeolocator.locationServiceEnabled = true;
    mockGeolocator.permission = LocationPermission.always;
    GeolocatorPlatform.instance = mockGeolocator;
    final controller = FakeMapController();
    final currentCenter = const LatLng(41.9, 12.5);
    late Future<LatLng> resultFuture;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            resultFuture = centerMapOnUser(context, currentCenter, controller, zoom: 12);
          },
          child: const Text('start'),
        ),
      ),
    ));

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result.latitude, 41.8902);
    expect(result.longitude, 12.4924);
  });

  testWidgets('DefaultMapManagementService properly delegates to helper functions', (tester) async {
    final controller = FakeMapController();
    final service = DefaultMapManagementService();
    
    // Testing moveCamera
    final resultMove = service.moveCamera(11.0, 22.0, 10.0, controller);
    expect(resultMove.latitude, 11.0);
    expect(resultMove.longitude, 22.0);

    // Testing dialogs & checks
    final mockGeolocator = MockGeolocatorPlatform();
    mockGeolocator.locationServiceEnabled = false; // Will trigger the service dialog
    GeolocatorPlatform.instance = mockGeolocator;

    late Future<LatLng> checkStartingFuture;
    late Future<LatLng> centerMapFuture;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Column(
          children: [
            ElevatedButton(
              onPressed: () {
                service.showPermissionDialog(context);
              },
              child: const Text('dialog 1'),
            ),
            ElevatedButton(
              onPressed: () {
                service.showServiceDialog(context);
              },
              child: const Text('dialog 2'),
            ),
            ElevatedButton(
              onPressed: () {
                checkStartingFuture = service.checkStartingLocation(context, controller, mapZoom: 10);
              },
              child: const Text('check'),
            ),
            ElevatedButton(
              onPressed: () {
                centerMapFuture = service.centerMap(context, const LatLng(0, 0), controller, zoom: 10);
              },
              child: const Text('center'),
            ),
          ],
        ),
      ),
    ));

    // Test Dialog 1
    await tester.tap(find.text('dialog 1'));
    await tester.pumpAndSettle();
    expect(find.text('Location permission required'), findsOneWidget);
    await tester.tap(find.text('Ignore'));
    await tester.pumpAndSettle();

    // Test Dialog 2
    await tester.tap(find.text('dialog 2'));
    await tester.pumpAndSettle();
    expect(find.text('Location service required'), findsOneWidget);
    await tester.tap(find.text('Ignore'));
    await tester.pumpAndSettle();

    // Test start location delegator
    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();
    expect(await checkStartingFuture, defaultMapCenter);
    await tester.tap(find.text('Ignore'));
    await tester.pumpAndSettle();

    // Test center map delegator
    await tester.tap(find.text('center'));
    await tester.pumpAndSettle();
    expect(await centerMapFuture, const LatLng(0, 0));
  });
}