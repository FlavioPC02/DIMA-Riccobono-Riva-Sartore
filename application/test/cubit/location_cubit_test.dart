//import 'dart:async';
//
//import 'package:application/core/cubit/location_cubit.dart';
//import 'package:application/core/models/location_point.dart';
//import 'package:bloc_test/bloc_test.dart';
//import 'package:flutter_test/flutter_test.dart';
//import 'package:mocktail/mocktail.dart';
//import '../mocks/mocks_manual.dart';
//import '../utils/test_config.dart';
//
//MockLocationRepository createMockRepo({
//  List<LocationPoint>? testPoints,
//}) {
//  final repo = MockLocationRepository();
//
//  when(() => repo.getAll()).thenReturn(testPoints ?? const []);
//  when(() => repo.save(any())).thenAnswer((_) async {});
//  when(() => repo.clear()).thenAnswer((_) async {});
//
//  return repo;
//}
//
//MockBackgroundTrackingService createMockBackgroundService({
//  Stream<LocationPoint>? locationStream,
//}) {
//  final service = MockBackgroundTrackingService();
//
//  when(() => service.startTracking()).thenAnswer((_) async {});
//  when(() => service.stopTracking()).thenAnswer((_) async {});
//  when(() => service.watchLocation()).thenAnswer(
//    (_) => locationStream ?? Stream<LocationPoint>.empty(),
//  );
//
//  return service;
//}
//
//LocationPoint point({
//  required double lat,
//  required double lng,
//  required double altitude,
//  required int secondsSinceEpoch,
//}) {
//  return LocationPoint(
//    lat: lat,
//    lng: lng,
//    altitude: altitude,
//    positionAccuracy: 5,
//    altitudeAccuracy: 5,
//    timestamp: DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000),
//  );
//}
//
//void main() {
//  setUpAll(() {
//    setupTest();
//  });
//
//  test('starts idle', () {
//    final cubit = LocationCubit(
//      createMockRepo(),
//      backgroundTrackingService: createMockBackgroundService(),
//    );
//
//    expect(cubit.state, const LocationState.idle());
//  });
//
//  blocTest<LocationCubit, LocationState>(
//    'startTracking rehydrates saved points and computes metrics',
//    build: () {
//      final savedPoints = [
//        point(lat: 0, lng: 0, altitude: 100, secondsSinceEpoch: 0),
//        point(lat: 0, lng: 0.001, altitude: 130, secondsSinceEpoch: 10),
//        point(lat: 0, lng: 0.002, altitude: 110, secondsSinceEpoch: 20),
//      ];
//      final repo = createMockRepo(testPoints: savedPoints);
//      final service = createMockBackgroundService();
//      return LocationCubit(
//        repo,
//        backgroundTrackingService: service,
//      );
//    },
//    act: (cubit) async {
//      await cubit.startTracking();
//    },
//    expect: () => [
//      isA<LocationState>()
//          .having((s) => s.isTracking, 'isTracking', true)
//          .having((s) => s.points.length, 'points length', 3)
//          .having((s) => s.current?.altitude, 'current altitude', 110)
//          .having((s) => s.distance, 'distance', closeTo(222.64, 1.0))
//          .having((s) => s.elevationGap, 'elevationGap', 10)
//          .having((s) => s.totalAscent, 'totalAscent', 30)
//          .having((s) => s.totalDescent, 'totalDescent', 20),
//      const LocationState.idle(),
//    ],
//  );
//
//  blocTest<LocationCubit, LocationState>(
//    'startTracking emits empty tracking state when repository is empty',
//    build: () => LocationCubit(
//      createMockRepo(),
//      backgroundTrackingService: createMockBackgroundService(),
//    ),
//    act: (cubit) async {
//      await cubit.startTracking();
//    },
//    expect: () => [
//      const LocationState.tracking(),
//      const LocationState.idle(),
//    ],
//  );
//
//  test('startTracking ignores repeated calls while already tracking', () async {
//    final repo = createMockRepo();
//    final service = createMockBackgroundService();
//    final cubit = LocationCubit(
//      repo,
//      backgroundTrackingService: service,
//    );
//
//    await cubit.startTracking();
//    await cubit.startTracking();
//
//    verify(() => repo.getAll()).called(1);
//    verify(() => service.startTracking()).called(1);
//    verify(() => service.watchLocation()).called(1);
//
//    await cubit.close();
//  });
//
//  test('incoming location updates emit new tracking state and persist the point', () async {
//    final repo = createMockRepo();
//    final streamController = StreamController<LocationPoint>();
//    final service = createMockBackgroundService(locationStream: streamController.stream);
//    final cubit = LocationCubit(
//      repo,
//      backgroundTrackingService: service,
//    );
//
//    await cubit.startTracking();
//
//    final firstPoint = point(lat: 0, lng: 0, altitude: 100, secondsSinceEpoch: 0);
//    final secondPoint = point(lat: 0, lng: 0.001, altitude: 125, secondsSinceEpoch: 10);
//
//    streamController.add(firstPoint);
//    await Future<void>.delayed(Duration.zero);
//
//    expect(cubit.state.points.length, 1);
//    expect(cubit.state.current, firstPoint);
//    expect(cubit.state.distance, 0);
//    expect(cubit.state.elevationGap, 0);
//    expect(cubit.state.totalAscent, 0);
//    expect(cubit.state.totalDescent, 0);
//
//    streamController.add(secondPoint);
//    await Future<void>.delayed(Duration.zero);
//
//    expect(cubit.state.points.length, 2);
//    expect(cubit.state.current, secondPoint);
//    expect(cubit.state.distance, closeTo(111.19, 1.0));
//    expect(cubit.state.elevationGap, 25);
//    expect(cubit.state.totalAscent, 25);
//    expect(cubit.state.totalDescent, 0);
//    verify(() => repo.save(firstPoint)).called(1);
//    verify(() => repo.save(secondPoint)).called(1);
//
//    await cubit.close();
//    await streamController.close();
//  });
//
//  test('background stream errors emit error state', () async {
//    final repo = createMockRepo();
//    final streamController = StreamController<LocationPoint>();
//    final service = createMockBackgroundService(locationStream: streamController.stream);
//    final cubit = LocationCubit(
//      repo,
//      backgroundTrackingService: service,
//    );
//
//    await cubit.startTracking();
//    streamController.addError('boom');
//    await Future<void>.delayed(Duration.zero);
//
//    expect(cubit.state, const LocationState.error('boom'));
//
//    await cubit.close();
//    await streamController.close();
//  });
//
//  test('stopTracking cancels the location subscription and emits idle', () async {
//    final repo = createMockRepo();
//    final streamController = StreamController<LocationPoint>();
//    final service = createMockBackgroundService(locationStream: streamController.stream);
//    var stopCalls = 0;
//
//    when(() => service.stopTracking()).thenAnswer((_) async {
//      stopCalls++;
//    });
//
//    final cubit = LocationCubit(
//      repo,
//      backgroundTrackingService: service,
//    );
//
//    await cubit.startTracking();
//    expect(streamController.hasListener, true);
//
//    await cubit.stopTracking();
//
//    expect(stopCalls, 1);
//    expect(cubit.state, const LocationState.idle());
//    expect(streamController.hasListener, false);
//
//    await streamController.close();
//  });
//
//  test('clearHistory clears the repository and preserves current location', () async {
//    final repo = createMockRepo();
//    final streamController = StreamController<LocationPoint>();
//    final service = createMockBackgroundService(locationStream: streamController.stream);
//    final cubit = LocationCubit(
//      repo,
//      backgroundTrackingService: service,
//    );
//
//    await cubit.startTracking();
//    final currentPoint = point(lat: 1, lng: 1, altitude: 50, secondsSinceEpoch: 0);
//    streamController.add(currentPoint);
//    await Future<void>.delayed(Duration.zero);
//
//    await cubit.clearHistory();
//
//    verify(() => repo.clear()).called(1);
//    expect(cubit.state.isTracking, true);
//    expect(cubit.state.points, isEmpty);
//    expect(cubit.state.current, currentPoint);
//
//    await cubit.close();
//    await streamController.close();
//  });
//
//  test('close stops tracking and cancels the stream subscription', () async {
//    final repo = createMockRepo();
//    final streamController = StreamController<LocationPoint>();
//    final service = createMockBackgroundService(locationStream: streamController.stream);
//    var stopCalls = 0;
//
//    when(() => service.stopTracking()).thenAnswer((_) async {
//      stopCalls++;
//    });
//
//    final cubit = LocationCubit(
//      repo,
//      backgroundTrackingService: service,
//    );
//
//    await cubit.startTracking();
//    expect(streamController.hasListener, true);
//
//    await cubit.close();
//
//    expect(stopCalls, 1);
//    expect(streamController.hasListener, false);
//    expect(cubit.isClosed, true);
//
//    await streamController.close();
//  });
//}
//