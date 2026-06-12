import 'dart:async';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:application/core/models/location_point.dart';
import 'package:application/services/helpers/background_service_helper.dart';

class MockFlutterBackgroundService extends Mock implements FlutterBackgroundService {}
class MockAndroidServiceInstance extends Mock implements AndroidServiceInstance {}
class MockServiceInstance extends Mock implements ServiceInstance {}

class MockGeolocatorPlatform extends GeolocatorPlatform {
  final StreamController<Position> positionStreamController = StreamController<Position>.broadcast();

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return positionStreamController.stream;
  }
}

class FakeIosConfiguration extends Fake implements IosConfiguration {}
class FakeAndroidConfiguration extends Fake implements AndroidConfiguration {}

void main() {
  late MockFlutterBackgroundService mockService;
  late MockGeolocatorPlatform mockGeolocator;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    
    registerFallbackValue(FakeIosConfiguration());
    registerFallbackValue(FakeAndroidConfiguration());
  });

  setUp(() {
    mockService = MockFlutterBackgroundService();
    sl.registerSingleton<FlutterBackgroundService>(mockService);
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
  });

  tearDown(() {
    sl.reset();
  });

  group('Background Service Control Functions', () {
    test('initializeBackgroundService should configure the service', () async {
      when(() => mockService.configure(
            iosConfiguration: any(named: 'iosConfiguration'),
            androidConfiguration: any(named: 'androidConfiguration'),
          )).thenAnswer((_) async => true);

      await initializeBackgroundService();

      verify(() => mockService.configure(
            iosConfiguration: any(named: 'iosConfiguration'),
            androidConfiguration: any(named: 'androidConfiguration'),
          )).called(1);
    });

    test('startBackgroundTracking should start if not running', () async {
      when(() => mockService.isRunning()).thenAnswer((_) async => false);
      when(() => mockService.startService()).thenAnswer((_) async => true);

      await startBackgroundTracking();

      verify(() => mockService.isRunning()).called(1);
      verify(() => mockService.startService()).called(1);
    });

    test('startBackgroundTracking should NOT start if already running', () async {
      when(() => mockService.isRunning()).thenAnswer((_) async => true);

      await startBackgroundTracking();

      verify(() => mockService.isRunning()).called(1);
      verifyNever(() => mockService.startService());
    });

    test('stopBackgroundTracking should invoke stopService', () async {
      when(() => mockService.invoke('stopService')).thenReturn(null);

      await stopBackgroundTracking();

      verify(() => mockService.invoke('stopService')).called(1);
    });
  });

  group('Data Stream Management', () {
    test('backgroundLocationStream correctly maps JSON data to LocationPoint', () async {
      final streamController = StreamController<Map<String, dynamic>?>();
      when(() => mockService.on('location')).thenAnswer((_) => streamController.stream);

      final stream = backgroundLocationStream;
      
      expectLater(
        stream,
        emits(isA<LocationPoint>().having((p) => p.lat, 'lat', 41.9)),
      );

      streamController.add({
        'lat': 41.9,
        'lng': 12.5,
        'altitude': 10.0,
        'positionAccuracy': 5.0,
        'altitudeAccuracy': 2.0,
        'timestamp': '2026-06-12T10:00:00.000Z',
      });

      await streamController.close();
    });
  });

  group('Background Entry Points', () {
    test('onBackgroundServiceStart (Android) handles foreground/background and listens to GPS', () async {
      final mockAndroidInstance = MockAndroidServiceInstance();
      
      final setAsForegroundController = StreamController<Map<String, dynamic>?>();
      final setAsBackgroundController = StreamController<Map<String, dynamic>?>();
      final stopServiceController = StreamController<Map<String, dynamic>?>();

      when(() => mockAndroidInstance.on('setAsForeground')).thenAnswer((_) => setAsForegroundController.stream);
      when(() => mockAndroidInstance.on('setAsBackground')).thenAnswer((_) => setAsBackgroundController.stream);
      when(() => mockAndroidInstance.on('stopService')).thenAnswer((_) => stopServiceController.stream);
      
      when(() => mockAndroidInstance.setAsForegroundService()).thenAnswer((_) async {});
      when(() => mockAndroidInstance.setAsBackgroundService()).thenAnswer((_) async {});
      when(() => mockAndroidInstance.invoke(any(), any())).thenReturn(null);

      onBackgroundServiceStart(mockAndroidInstance);

      setAsForegroundController.add({});
      await Future.delayed(Duration.zero);
      verify(() => mockAndroidInstance.setAsForegroundService()).called(1);

      setAsBackgroundController.add({});
      await Future.delayed(Duration.zero);
      verify(() => mockAndroidInstance.setAsBackgroundService()).called(1);

      final testPosition = Position(
        longitude: 12.5, latitude: 41.9, timestamp: DateTime.now(),
        accuracy: 10.0, altitude: 20.0, altitudeAccuracy: 5.0,
        heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
      );
      
      mockGeolocator.positionStreamController.add(testPosition);
      await Future.delayed(Duration.zero);

      verify(() => mockAndroidInstance.invoke('location', any())).called(1);

      await setAsForegroundController.close();
      await setAsBackgroundController.close();
      await stopServiceController.close();
    });

    test('_onIosBackground should return true and initialize plugins', () async {
      final mockInstance = MockServiceInstance();
      final result = await onIosBackground(mockInstance);
      expect(result, isTrue);
    });
  });
}