import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:application/services/helpers/map_management_service_helper.dart';

class MockGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  bool locationServiceEnabled = true;
  LocationPermission permission = LocationPermission.always;

  bool requestPermissionCalled = false;
  bool openLocationSettingsCalled = false;

  @override
  Future<bool> isLocationServiceEnabled() async => locationServiceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalled = true;
    return permission;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalled = true;
    return true;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
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
  late MockGeolocatorPlatform mockGeolocator;

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
  });

  testWidgets(
    'showLocationPermissionDialog renders required title and buttons',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showLocationPermissionDialog(context),
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Location permission required'), findsOneWidget);
      expect(find.text('Enable location permission'), findsOneWidget);
      expect(find.text('Ignore'), findsOneWidget);
    },
  );

  testWidgets('showLocationPermissionDialog ignores concurrent requests', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showLocationPermissionDialog(context);
                showLocationPermissionDialog(context);
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Location permission required'), findsOneWidget);
  });

  testWidgets(
    'showLocationPermissionDialog: calls requestPermission on Enable and pops',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showLocationPermissionDialog(context),
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable location permission'));
      await tester.pumpAndSettle();

      expect(mockGeolocator.requestPermissionCalled, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('showLocationPermissionDialog: pops on Ignore', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showLocationPermissionDialog(context),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ignore'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('showLocationServiceDialog renders required title and buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showLocationServiceDialog(context),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Location service required'), findsOneWidget);
  });

  testWidgets(
    'showLocationServiceDialog: calls openLocationSettings on Enable and pops',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showLocationServiceDialog(context),
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable location service'));
      await tester.pumpAndSettle();

      expect(mockGeolocator.openLocationSettingsCalled, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('showLocationServiceDialog: pops on Ignore', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showLocationServiceDialog(context),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ignore'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'checkInitialLocation returns default map center when service disabled',
    (tester) async {
      mockGeolocator.locationServiceEnabled = false;
      final controller = MapController();
      late Future<LatLng> resultFuture;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  resultFuture = checkInitialLocation(context, controller);
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Location service required'), findsOneWidget);
      expect(await resultFuture, defaultMapCenter);
    },
  );

  testWidgets(
    'checkInitialLocation returns default map center when permission denied',
    (tester) async {
      mockGeolocator.locationServiceEnabled = true;
      mockGeolocator.permission = LocationPermission.denied;
      final controller = MapController();
      late Future<LatLng> resultFuture;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  resultFuture = checkInitialLocation(context, controller);
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Location permission required'), findsOneWidget);
      expect(await resultFuture, defaultMapCenter);
    },
  );

  testWidgets('checkInitialLocation returns current position on success', (
    tester,
  ) async {
    mockGeolocator.locationServiceEnabled = true;
    mockGeolocator.permission = LocationPermission.always;
    final controller = MapController();
    late Future<LatLng> resultFuture;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  Expanded(
                    child: FlutterMap(
                      mapController: controller,
                      options: const MapOptions(),
                      children: const [],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      resultFuture = checkInitialLocation(context, controller);
                    },
                    child: const Text('open'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result.latitude, 41.8902);
    expect(result.longitude, 12.4924);
  });

  testWidgets('centerMapOnUser returns current center when service disabled', (
    tester,
  ) async {
    mockGeolocator.locationServiceEnabled = false;
    final controller = MapController();
    final currentCenter = const LatLng(41.9, 12.5);
    late Future<LatLng> resultFuture;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                resultFuture = centerMapOnUser(
                  context,
                  currentCenter,
                  controller,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Location service required'), findsOneWidget);
    expect(await resultFuture, currentCenter);
  });

  testWidgets(
    'centerMapOnUser returns current center when permission is denied',
    (tester) async {
      mockGeolocator.locationServiceEnabled = true;
      mockGeolocator.permission = LocationPermission.denied;
      final controller = MapController();
      final currentCenter = const LatLng(41.9, 12.5);
      late Future<LatLng> resultFuture;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  resultFuture = centerMapOnUser(
                    context,
                    currentCenter,
                    controller,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Location permission required'), findsOneWidget);
      expect(await resultFuture, currentCenter);
    },
  );

  testWidgets('centerMapOnUser returns new position on success', (
    tester,
  ) async {
    mockGeolocator.locationServiceEnabled = true;
    mockGeolocator.permission = LocationPermission.always;
    final controller = MapController();
    final currentCenter = const LatLng(41.9, 12.5);
    late Future<LatLng> resultFuture;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  Expanded(
                    child: FlutterMap(
                      mapController: controller,
                      options: const MapOptions(),
                      children: const [],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      resultFuture = centerMapOnUser(
                        context,
                        currentCenter,
                        controller,
                      );
                    },
                    child: const Text('open'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result.latitude, 41.8902);
    expect(result.longitude, 12.4924);
  });

  testWidgets('moveCameraTo returns the correct LatLng', (tester) async {
    final controller = MapController();
    const lat = 42.0;
    const lng = 13.0;
    late LatLng result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            mapController: controller,
            options: const MapOptions(),
            children: const [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    result = moveCameraTo(lat, lng, 10, controller);

    expect(result.latitude, lat);
    expect(result.longitude, lng);
  });
}
