import 'dart:async';
import 'dart:ui';

import 'package:application/core/models/location_point.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';

const _notificationChannelId = 'gps_tracker_channel';
const _notificationChannelName = 'GPS Tracker';
const _notificationId = 888;

StreamSubscription<Position>? _positionSub;

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      onForeground: onBackgroundServiceStart,
      onBackground: _onIosBackground,
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
  final service = FlutterBackgroundService();
  final isRunning = await service.isRunning();
  if (!isRunning) await service.startService();
}

Future<void> stopBackgroundTracking() async {
  final service = FlutterBackgroundService();
  service.invoke('stopService');
}

//stream of LocationPoint forwarded from the background isolate to the main isolate
Stream<LocationPoint> get backgroundLocationStream {
  return FlutterBackgroundService()
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

  //initialize Hive in background isolate
  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  //Hive.registerAdapter<LocationPoint>(LocationPointAdapter());
  final box = await Hive.openBox<LocationPoint>('location_box');

  //Android foreground notification update
  if(service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) async {
    await _positionSub?.cancel();
    await box.close();
    await service.stopSelf();
  });

  final locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
    intervalDuration: Duration(seconds: 5),
    foregroundNotificationConfig: ForegroundNotificationConfig(
      notificationTitle: _notificationChannelName, 
      notificationText: 'GPS tracker is tracking your position',
      enableWakeLock: true,
    ),
  );

  _positionSub = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((Position pos) async {
    final point = LocationPoint(
      lat: pos.latitude, 
      lng: pos.longitude, 
      altitude: pos.altitude, 
      positionAccuracy: pos.accuracy, 
      altitudeAccuracy: pos.altitudeAccuracy, 
      timestamp: pos.timestamp,
    );

    await box.add(point);

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
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

