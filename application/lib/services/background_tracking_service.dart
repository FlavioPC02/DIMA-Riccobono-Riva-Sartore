import 'package:application/core/models/location_point.dart';
import 'package:application/services/helpers/background_service_helper.dart';

abstract class BackgroundTrackingService {
  Future<void> initialize();

  Future<void> startTracking();

  Future<void> stopTracking();

  Stream<LocationPoint> watchLocation();
}

// coverage:ignore-start
class BackgroundServiceWrapper {
  const BackgroundServiceWrapper();

  Future<void> initialize() => initializeBackgroundService();
  Future<void> start() => startBackgroundTracking();
  Future<void> stop() => stopBackgroundTracking();
  Stream<LocationPoint> get locationStream => backgroundLocationStream;
}
// coverage:ignore-end

class DefaultBackgroundTrackingService implements BackgroundTrackingService {
  final BackgroundServiceWrapper _wrapper;

  DefaultBackgroundTrackingService({BackgroundServiceWrapper? wrapper})
    : _wrapper = wrapper ?? const BackgroundServiceWrapper();
    
  @override
  Future<void> initialize() => _wrapper.initialize();

  @override
  Future<void> startTracking() => _wrapper.start();

  @override
  Future<void> stopTracking() => _wrapper.stop();

  @override
  Stream<LocationPoint> watchLocation() => _wrapper.locationStream;
}