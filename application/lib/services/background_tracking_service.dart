import 'package:application/core/models/location_point.dart';
import 'package:application/services/helpers/background_service_helper.dart';

abstract class BackgroundTrackingService {
  Future<void> initialize();

  Future<void> startTracking();

  Future<void> stopTracking();

  Stream<LocationPoint> watchLocation();
}

class DefaultBackgroundTrackingService implements BackgroundTrackingService {
  @override
  Future<void> initialize() => initializeBackgroundService();

  @override
  Future<void> startTracking() => startBackgroundTracking();

  @override
  Future<void> stopTracking() => stopBackgroundTracking();

  @override
  Stream<LocationPoint> watchLocation() => backgroundLocationStream;
}