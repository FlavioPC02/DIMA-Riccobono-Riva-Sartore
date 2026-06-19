import '../core/models/location_point.dart';
import 'helpers/background_service_helper.dart';

abstract class BackgroundTrackingService {
  Future<void> initialize();

  Future<void> startTracking();

  Future<void> stopTracking();

  Stream<LocationPoint> watchLocation();
}

class BackgroundServiceWrapper {
  const BackgroundServiceWrapper();

  Future<void> initialize() => initializeBackgroundService();
  Future<void> start() => startBackgroundTracking();
  Future<void> stop() => stopBackgroundTracking();
  Stream<LocationPoint> get locationStream => backgroundLocationStream;
}

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