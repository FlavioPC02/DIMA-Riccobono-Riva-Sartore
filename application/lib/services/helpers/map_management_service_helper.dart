// dialog shown when location permissions are denied
import 'package:hike_core/src/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';

const LatLng defaultMapCenter = LatLng(41.8967, 12.4822);

void showLocationPermissionDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Location permission required',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Without enabling the permission, it is not possible to obtain the current location.',
          textAlign: TextAlign.center,
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  //request location permissions
                  await geo.Geolocator.requestPermission();
                },
                child: const Text('Enable location permission'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorBackground,
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Ignore',
                  style: TextStyle(color: AppColors.errorText),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

// dialog shown when location services are disabled
void showLocationServiceDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Location service required',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Enable GPS to obtain the current location.',
          textAlign: TextAlign.center,
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  //open device settings to allow the user to enable location services
                  geo.Geolocator.openLocationSettings();
                },
                child: const Text('Enable location permission'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorBackground,
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Ignore',
                  style: TextStyle(color: AppColors.errorText),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

//when the widget is first built, check if location services are enabled and permissions are granted, then fetch the current location
Future<LatLng> checkInitialLocation(
  BuildContext context,
  MapController mapController, {
  double mapZoom = 12,
}) async {
  bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    showLocationServiceDialog(context);
    return defaultMapCenter;
  }

  geo.LocationPermission permission = await geo.Geolocator.checkPermission();
  if (permission == geo.LocationPermission.denied ||
      permission == geo.LocationPermission.deniedForever) {
    showLocationPermissionDialog(context);
    return defaultMapCenter;
  }

  //fetch the current location and center the map on it
  geo.Position position = await geo.Geolocator.getCurrentPosition();
  return moveCameraTo(
    position.latitude,
    position.longitude,
    mapZoom,
    mapController,
  );
}

//function to move the camera to a specific location with a given zoom level
LatLng moveCameraTo(
  double lat,
  double lng,
  double zoom,
  MapController mapController,
) {
  final currentCenter = LatLng(lat, lng);
  mapController.move(currentCenter, zoom);

  return currentCenter;
}

//when the location button is pressed, check permissions and fetch the current location, then center the map on it
Future<LatLng> centerMapOnUser(BuildContext context, LatLng currentCenter, MapController mapController, {double zoom = 12}) async {
  var center = currentCenter;

  bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
  geo.LocationPermission permission = await geo.Geolocator.checkPermission();

  if (!serviceEnabled) {
    showLocationServiceDialog(context);
    return center;
  }

  if (permission == geo.LocationPermission.denied ||
      permission == geo.LocationPermission.deniedForever) {
    showLocationPermissionDialog(context);
    return center;
  }

  geo.Position position = await geo.Geolocator.getCurrentPosition();
  if (context.mounted) {
    center = moveCameraTo(
      position.latitude,
      position.longitude,
      zoom,
      mapController,
    );
  }

  return center;
}
