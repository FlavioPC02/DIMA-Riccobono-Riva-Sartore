import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:application/core/models/location_point.dart';
import 'package:application/services/background_tracking_service.dart';

import '../mocks/mocks_manual.dart';

class MockBackgroundServiceWrapper extends Mock implements BackgroundServiceWrapper {}

void main() {
  late DefaultBackgroundTrackingService trackingService;
  late MockBackgroundServiceWrapper mockWrapper;

  setUp(() {
    mockWrapper = MockBackgroundServiceWrapper();
    
    trackingService = DefaultBackgroundTrackingService(wrapper: mockWrapper);
  });

  group('constructor', () {
    test('instantiates with default BackgroundServiceWrapper when no wrapper is provided', () {
      final service = DefaultBackgroundTrackingService();
      expect(service, isA<DefaultBackgroundTrackingService>());
    });
  });

  group('delegation', () {
    test('delegates lifecycle calls and location stream to the wrapper', () async {
      final fakeStream = Stream<LocationPoint>.value(
        LocationPoint(
          lat: 45.1,
          lng: 9.1,
          altitude: 100.0,
          positionAccuracy: 5.0,
          altitudeAccuracy: 5.0,
          timestamp: DateTime(2026, 7, 1),
        ),
      );

      when(() => mockWrapper.initialize()).thenAnswer((_) async {});
      when(() => mockWrapper.start()).thenAnswer((_) async {});
      when(() => mockWrapper.stop()).thenAnswer((_) async {});
      when(() => mockWrapper.locationStream).thenAnswer((_) => fakeStream);

      await trackingService.initialize();
      await trackingService.startTracking();
      await trackingService.stopTracking();

      final result = await trackingService.watchLocation().first;

      expect(result.lat, 45.1);
      expect(result.lng, 9.1);
      verify(() => mockWrapper.initialize()).called(1);
      verify(() => mockWrapper.start()).called(1);
      verify(() => mockWrapper.stop()).called(1);
      verify(() => mockWrapper.locationStream).called(1);
    });
  });

  group('initialize', () {
    test('calls initialize on the wrapper', () async {
      when(() => mockWrapper.initialize()).thenAnswer((_) async {});

      await trackingService.initialize();

      verify(() => mockWrapper.initialize()).called(1);
    });
  });

  group('startTracking', () {
    test('calls start on the wrapper', () async {
      when(() => mockWrapper.start()).thenAnswer((_) async {});

      await trackingService.startTracking();

      verify(() => mockWrapper.start()).called(1);
    });
  });

  group('stopTracking', () {
    test('calls stop on the wrapper', () async {
      when(() => mockWrapper.stop()).thenAnswer((_) async {});

      await trackingService.stopTracking();

      verify(() => mockWrapper.stop()).called(1);
    });
  });

  group('watchLocation', () {
    test('returns the location stream from the wrapper', () {
      final fakeStream = Stream<LocationPoint>.fromIterable([FakeLocationPoint()]);
      when(() => mockWrapper.locationStream).thenAnswer((_) => fakeStream);

      final result = trackingService.watchLocation();

      expect(result, equals(fakeStream));
      verify(() => mockWrapper.locationStream).called(1);
    });
  });
}