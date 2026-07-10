import 'package:flutter/widgets.dart';
import 'package:application/services/helpers/map_management_service_helper.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

abstract class MapManagementService {
  void showPermissionDialog(BuildContext context);

  void showServiceDialog(BuildContext context);

  Future<bool> checkPermissions();

  Future<LatLng> checkStartingLocation(
    BuildContext context,
    MapController mapController, {
    double mapZoom = 12,
  });

  LatLng moveCamera(
    double lat,
    double lng,
    double zoom,
    MapController mapController,
  );

  Future<LatLng> centerMap(
    BuildContext context,
    LatLng currentCenter,
    MapController mapController, {
    double zoom = 12,
  });
}

class DefaultMapManagementService implements MapManagementService {
  @override
  void showPermissionDialog(BuildContext context) =>
      showLocationPermissionDialog(context);

  @override
  void showServiceDialog(BuildContext context) =>
      showLocationServiceDialog(context);

  @override
  Future<bool> checkPermissions() => checkLocationPermissions();

  @override
  Future<LatLng> checkStartingLocation(
    BuildContext context,
    MapController mapController, {
    double mapZoom = 12,
  }) => checkInitialLocation(context, mapController, mapZoom: mapZoom);

  @override
  LatLng moveCamera(
    double lat,
    double lng,
    double zoom,
    MapController mapController,
  ) => moveCameraTo(lat, lng, zoom, mapController);

  @override
  Future<LatLng> centerMap(
    BuildContext context,
    LatLng currentCenter,
    MapController mapController, {
    double zoom = 12,
  }) => centerMapOnUser(context, currentCenter, mapController, zoom: zoom);
}
