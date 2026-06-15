import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';

import '../../core/models/location_point.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';

const _notificationChannelName = 'GPS Tracker';
const _notificationId = 888;

StreamSubscription<Position>? _positionSub;

final sl = GetIt.instance;

Future<void> initializeBackgroundService() async {
  final service = sl.isRegistered<FlutterBackgroundService>() 
      ? sl<FlutterBackgroundService>() 
      : FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      onForeground: onBackgroundServiceStart,
      onBackground: onIosBackground,
      autoStart: false,
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundServiceStart,
      isForegroundMode: true,
      autoStart: false,
      initialNotificationTitle: 'GPS tracker',
      initialNotificationContent: 'Tracking your location...',
      foregroundServiceNotificationId: _notificationId,
    ),
  );
}

Future<void> startBackgroundTracking() async {
  final service = sl.isRegistered<FlutterBackgroundService>() 
      ? sl<FlutterBackgroundService>() 
      : FlutterBackgroundService();
  final isRunning = await service.isRunning();
  if (!isRunning) await service.startService();
}

Future<void> stopBackgroundTracking() async {
  final service = sl.isRegistered<FlutterBackgroundService>() 
      ? sl<FlutterBackgroundService>() 
      : FlutterBackgroundService();
  service.invoke('stopService');
}

//stream of LocationPoint forwarded from the background isolate to the main isolate
Stream<LocationPoint> get backgroundLocationStream {
  final service = sl.isRegistered<FlutterBackgroundService>() 
      ? sl<FlutterBackgroundService>() 
      : FlutterBackgroundService();

  return service
    .on('location')
    .map((data) => LocationPoint(
      lat: (data?['lat'] as num).toDouble(), 
      lng: (data?['lng'] as num).toDouble(), 
      altitude: (data?['altitude'] as num).toDouble(), 
      positionAccuracy: (data?['positionAccuracy'] as num).toDouble(), 
      altitudeAccuracy: (data?['altitudeAccuracy'] as num).toDouble(), 
      timestamp: DateTime.parse(data?['timestamp'] as String),
    ));
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  //make platform channels work in background isolate
  DartPluginRegistrant.ensureInitialized();

  //Android foreground notification update
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) async {
    await _positionSub?.cancel();
    await service.stopSelf();
  });

  final LocationSettings locationSettings;
  if (Platform.isIOS) {
    locationSettings = AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      activityType: ActivityType.fitness,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  } else {
    locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      intervalDuration: Duration(seconds: 5),
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: _notificationChannelName,
        notificationText: 'GPS tracker is tracking your position',
        enableWakeLock: true,
      ),
    );
  }

  _positionSub =
      Geolocator.getPositionStream(locationSettings: locationSettings).listen((
        Position pos,
      ) async {

        final point = LocationPoint(
          lat: pos.latitude,
          lng: pos.longitude,
          altitude: pos.altitude,
          positionAccuracy: pos.accuracy,
          altitudeAccuracy: pos.altitudeAccuracy,
          timestamp: pos.timestamp,
        );

        service.invoke('location', {
          'lat': point.lat,
          'lng': point.lng,
          'altitude': point.altitude,
          'positionAccuracy': point.positionAccuracy,
          'altitudeAccuracy': point.altitudeAccuracy,
          'timestamp': point.timestamp.toIso8601String(),
        });
      });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
