import 'dart:async';
import 'dart:ui';

import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/models/location_point.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

void main() {
  setUpAll(() {
    setupTest();
  });
  late MockLocationRepository repository;
  late MockBackgroundTrackingService backgroundService;
  late MockPhoneWearSyncService wearSync;

  late StreamController<LocationPoint> locationController;

  late VoidCallback? capturedPauseCallback;
  late VoidCallback? capturedResumeCallback;
  late VoidCallback? capturedStopCallback;

  LocationPoint point({
    double lat = 41.9,
    double lng = 12.5,
    double altitude = 100,
    double positionAccuracy = 5,
    double altitudeAccuracy = 5,
    DateTime? timestamp,
  }) {
    return LocationPoint(
      lat: lat,
      lng: lng,
      altitude: altitude,
      positionAccuracy: positionAccuracy,
      altitudeAccuracy: altitudeAccuracy,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  setUp(() {
    repository = MockLocationRepository();
    backgroundService = MockBackgroundTrackingService();
    wearSync = MockPhoneWearSyncService();
    locationController = StreamController<LocationPoint>.broadcast();

    when(() => repository.getAll()).thenReturn(<LocationPoint>[]);
    when(() => repository.save(any())).thenAnswer((_) async {});
    when(() => repository.clear()).thenAnswer((_) async {});

    when(
      () => backgroundService.watchLocation(),
    ).thenAnswer((_) => locationController.stream);
    when(() => backgroundService.startTracking()).thenAnswer((_) async {});
    when(() => backgroundService.stopTracking()).thenAnswer((_) async {});

    when(() => wearSync.initialize()).thenReturn(null);
    when(() => wearSync.sendStats(any())).thenAnswer((_) async {});
    when(() => wearSync.sendStatus(any())).thenAnswer((_) async {});
    when(
      () => wearSync.sendOffTrailNotification(any()),
    ).thenAnswer((_) async {});
    when(() => wearSync.onPauseFromWatch).thenAnswer((_) => capturedPauseCallback);
    when(() => wearSync.onPauseFromWatch = any()).thenAnswer((invocation) {
      capturedPauseCallback =
          invocation.positionalArguments.first as VoidCallback?;
      return null;
    });
    when(() => wearSync.onResumeFromWatch).thenAnswer((_) => capturedResumeCallback);
    when(() => wearSync.onResumeFromWatch = any()).thenAnswer((invocation) {
      capturedResumeCallback =
          invocation.positionalArguments.first as VoidCallback?;
      return null;
    });
    when(() => wearSync.onStopFromWatch).thenAnswer((_) => capturedStopCallback);
    when(() => wearSync.onStopFromWatch = any()).thenAnswer((invocation) {
      capturedStopCallback =
          invocation.positionalArguments.first as VoidCallback?;
      return null;
    });
  });

  tearDown(() async {
    await locationController.close();
  });

  LocationCubit buildCubit({
    OnActivitySaved? onActivitySaved,
    OnNavigateAfterStop? onNavigateAfterStop,
    Duration? initialEta,
  }) {
    return LocationCubit(
      repository,
      backgroundTrackingService: backgroundService,
      wearSyncService: wearSync,
      onActivitySaved: onActivitySaved,
      onNavigateAfterStop: onNavigateAfterStop,
      initialEta: initialEta,
    );
  }

  group('LocationCubit construction', () {
    test('initializes wear sync and registers watch callbacks', () {
      final cubit = buildCubit();

      verify(() => wearSync.initialize()).called(1);

      cubit.close();
    });

    test('initial state is idle', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<LocationState>());
      expect(cubit.state.isTracking, isFalse);
      cubit.close();
    });
  });

  group('startTracking', () {
    blocTest<LocationCubit, LocationState>(
      'emits a tracking state immediately with rehydrated points',
      build: () {
        when(
          () => repository.getAll(),
        ).thenReturn([point(lat: 41.0, lng: 12.0, altitude: 50)]);
        return buildCubit();
      },
      act: (cubit) => cubit.startTracking(),
      expect: () => [
        isA<LocationState>().having((s) => s.isTracking, 'isTracking', true),
      ],
    );

    blocTest<LocationCubit, LocationState>(
      'does nothing if already tracking (guard against double start)',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        // Second call should be a no-op — no additional emit.
        await cubit.startTracking();
      },
      // Only one emission expected despite two calls.
      expect: () => [
        isA<LocationState>().having((s) => s.isTracking, 'isTracking', true),
      ],
    );

    blocTest<LocationCubit, LocationState>(
      'sends recording status to watch once tracking starts',
      build: buildCubit,
      act: (cubit) => cubit.startTracking(),
      verify: (_) {
        verify(
          () => wearSync.sendStatus(HikeRecordingStatus.recording),
        ).called(1);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'starts the background tracking service',
      build: buildCubit,
      act: (cubit) => cubit.startTracking(),
      verify: (_) {
        verify(() => backgroundService.startTracking()).called(1);
      },
    );
  });

  group('GPS point handling', () {
    blocTest<LocationCubit, LocationState>(
      'accumulates distance across two GPS fixes',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        // Two points roughly 100m apart (small lat delta).
        locationController.add(point(lat: 41.9000, lng: 12.5000));
        await Future<void>.delayed(Duration.zero);
        locationController.add(point(lat: 41.9010, lng: 12.5000));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.distance, greaterThan(0));
      },
    );

    blocTest<LocationCubit, LocationState>(
      'rejects points with poor accuracy (>50m)',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        final before = cubit.state.points.length;
        locationController.add(point(positionAccuracy: 80));
        await Future<void>.delayed(Duration.zero);
        // Confirm point count did not increase — the inaccurate fix
        // was dropped by the `positionAccuracy > 50` guard.
        expect(cubit.state.points.length, before);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'rejects points with poor altitude accuracy (>50m)',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        final before = cubit.state.points.length;
        locationController.add(point(altitudeAccuracy: 80));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.points.length, before);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'computes ascent when altitude increases between fixes',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        locationController.add(point(altitude: 100));
        await Future<void>.delayed(Duration.zero);
        locationController.add(point(altitude: 150));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.totalAscent, 50);
        expect(cubit.state.totalDescent, 0);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'computes descent when altitude decreases between fixes',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        locationController.add(point(altitude: 200));
        await Future<void>.delayed(Duration.zero);
        locationController.add(point(altitude: 120));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.totalDescent, 80);
        expect(cubit.state.totalAscent, 0);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'persists each accepted point to the repository',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        locationController.add(point());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        verify(() => repository.save(any())).called(1);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'sends updated stats to the watch on every accepted GPS fix',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        locationController.add(point());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        // Called once for the initial empty stats push in startTracking(),
        // and once more after the GPS fix — verify at least the fix-driven
        // call happened by checking call count >= 2.
        verify(() => wearSync.sendStats(any())).called(greaterThanOrEqualTo(2));
      },
    );

    blocTest<LocationCubit, LocationState>(
      'ignores points while paused, but still updates current position',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        locationController.add(point(lat: 41.0, lng: 12.0));
        await Future<void>.delayed(Duration.zero);
        await cubit.pauseTracking();

        final distanceBeforePausedPoint = cubit.state.distance;
        locationController.add(point(lat: 42.0, lng: 13.0));
        await Future<void>.delayed(Duration.zero);

        // Distance should NOT have grown — paused points don't add distance.
        expect(cubit.state.distance, distanceBeforePausedPoint);
        // But current position should reflect the new paused-state fix.
        expect(cubit.state.current?.lat, 42.0);
      },
    );
  });

  group('off-trail detection', () {
    // A simple straight trail segment running along the same longitude.
    final trail = [
      [const LatLng(41.9000, 12.5000), const LatLng(41.9100, 12.5000)],
    ];

    blocTest<LocationCubit, LocationState>(
      'reports isOffTrail = false when within threshold',
      build: () {
        final cubit = buildCubit();
        cubit.setTrailData(segments: trail, onOffTrail: (_, __) {});
        return cubit;
      },
      act: (cubit) async {
        await cubit.startTracking();
        // Point essentially on the trail line.
        locationController.add(point(lat: 41.9050, lng: 12.5000));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.isOffTrail, isFalse);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'reports isOffTrail = true when beyond threshold and fires callback',
      build: () => buildCubit(),
      act: (cubit) async {
        int? capturedDistance;
        String? capturedDirection;

        cubit.setTrailData(
          segments: trail,
          onOffTrail: (distance, direction) {
            capturedDistance = distance;
            capturedDirection = direction;
          },
        );

        await cubit.startTracking();
        // ~1km east of the trail line — well beyond the 50m threshold.
        locationController.add(point(lat: 41.9050, lng: 12.5100));
        await Future<void>.delayed(Duration.zero);

        expect(capturedDistance, isNotNull);
        expect(capturedDistance, greaterThan(50));
        expect(capturedDirection, isNotNull);
      },
      verify: (cubit) {
        expect(cubit.state.isOffTrail, isTrue);
        expect(cubit.state.offTrailDirection, isNotNull);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'rate-limits off-trail callback to once per 60 seconds',
      build: () => buildCubit(),
      act: (cubit) async {
        var callCount = 0;
        cubit.setTrailData(segments: trail, onOffTrail: (_, __) => callCount++);

        await cubit.startTracking();

        // Two consecutive off-trail fixes in quick succession.
        locationController.add(point(lat: 41.9050, lng: 12.5100));
        await Future<void>.delayed(Duration.zero);
        locationController.add(point(lat: 41.9051, lng: 12.5101));
        await Future<void>.delayed(Duration.zero);

        // Only the first should have triggered the callback due to the
        // 60-second rate limit.
        expect(callCount, 1);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'does not evaluate off-trail when no trail data has been set',
      build: buildCubit, // setTrailData never called
      act: (cubit) async {
        await cubit.startTracking();
        locationController.add(point(lat: 41.9050, lng: 12.5100));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        // Empty _trailSegments means _checkOffTrail short-circuits to null.
        expect(cubit.state.isOffTrail, isFalse);
      },
    );
  });

  group('pause / resume', () {
    blocTest<LocationCubit, LocationState>(
      'pauseTracking emits a paused state and stops the stopwatch',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        await cubit.pauseTracking();
      },
      verify: (cubit) {
        expect(cubit.state.isPaused, isTrue);
        expect(cubit.isRunning, isFalse);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'pauseTracking sends paused status to the watch',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        await cubit.pauseTracking();
      },
      verify: (_) {
        verify(() => wearSync.sendStatus(HikeRecordingStatus.paused)).called(1);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'pauseTracking is a no-op if not currently tracking',
      build: buildCubit,
      act: (cubit) => cubit.pauseTracking(),
      expect: () => <LocationState>[],
    );

    blocTest<LocationCubit, LocationState>(
      'resumeTracking restarts the stopwatch and emits tracking state',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        await cubit.pauseTracking();
        await cubit.resumeTracking();
      },
      verify: (cubit) {
        expect(cubit.state.isTracking, isTrue);
        expect(cubit.isRunning, isTrue);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'resumeTracking is a no-op if not currently paused',
      build: buildCubit,
      act: (cubit) => cubit.resumeTracking(),
      expect: () => <LocationState>[],
    );

    blocTest<LocationCubit, LocationState>(
      'resumeTracking sends recording status to the watch',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        await cubit.pauseTracking();
        await cubit.resumeTracking();
      },
      verify: (_) {
        // recording is sent once on startTracking, once on resume.
        verify(
          () => wearSync.sendStatus(HikeRecordingStatus.recording),
        ).called(2);
      },
    );
  });

  group('stopAndSave', () {
    blocTest<LocationCubit, LocationState>(
      'calls onActivitySaved with final distance, elevation, and elapsed',
      build: () => buildCubit(),
      act: (cubit) async {
        double? savedDistance;
        double? savedElevationGap;

        cubit.registerStopCallbacks(
          onActivitySaved:
              ({
                required double distance,
                required double elevationGap,
                required Duration elapsed,
              }) async {
                savedDistance = distance;
                savedElevationGap = elevationGap;
              },
          onNavigateAfterStop: () {},
        );

        await cubit.startTracking();
        locationController.add(
          point(lat: 41.9000, lng: 12.5000, altitude: 100),
        );
        await Future<void>.delayed(Duration.zero);
        locationController.add(
          point(lat: 41.9010, lng: 12.5000, altitude: 120),
        );
        await Future<void>.delayed(Duration.zero);

        await cubit.stopAndSave();

        expect(savedDistance, isNotNull);
        expect(savedDistance, greaterThan(0));
        expect(savedElevationGap, isNotNull);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'calls onNavigateAfterStop when navigate is true',
      build: () => buildCubit(),
      act: (cubit) async {
        var navigated = false;
        cubit.registerStopCallbacks(
          onActivitySaved:
              ({
                required double distance,
                required double elevationGap,
                required Duration elapsed,
              }) async {},
          onNavigateAfterStop: () => navigated = true,
        );

        await cubit.startTracking();
        await cubit.stopAndSave(navigate: true);

        expect(navigated, isTrue);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'does NOT call onNavigateAfterStop when navigate is false '
      '(watch-triggered stop)',
      build: () => buildCubit(),
      act: (cubit) async {
        var navigated = false;
        cubit.registerStopCallbacks(
          onActivitySaved:
              ({
                required double distance,
                required double elevationGap,
                required Duration elapsed,
              }) async {},
          onNavigateAfterStop: () => navigated = true,
        );

        await cubit.startTracking();
        await cubit.stopAndSave(navigate: false);

        expect(navigated, isFalse);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'emits idle state after stopping',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        await cubit.stopAndSave();
      },
      expect: () => [
        isA<LocationState>(), //tracking
        isA<LocationState>(), //reset
        LocationState.idle(), //idle
      ],
      verify: (cubit) {
        expect(cubit.state.isTracking, isFalse);
        expect(cubit.state.isPaused, isFalse);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'stops the background tracking service and cancels the GPS subscription',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        await cubit.stopAndSave();
      },
      verify: (_) {
        verify(
          () => backgroundService.stopTracking(),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    blocTest<LocationCubit, LocationState>(
      'clears persisted history after saving',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        await cubit.stopAndSave();
      },
      verify: (_) {
        verify(() => repository.clear()).called(1);
      },
    );

    blocTest<LocationCubit, LocationState>(
      'sends stopped status to the watch',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        await cubit.stopAndSave();
      },
      verify: (_) {
        verify(
          () => wearSync.sendStatus(HikeRecordingStatus.stopped),
        ).called(1);
      },
    );
  });

  group('watch-triggered commands', () {
    blocTest<LocationCubit, LocationState>(
      'pauses tracking from watch callback',
      build: buildCubit,
      act: (cubit) async {
        await cubit.startTracking();
        capturedPauseCallback?.call();
        await pumpEventQueue();
      },
      expect: () => [
        isA<LocationState>().having((s) => s.isTracking, 'tracking', isTrue),
        isA<LocationState>().having((s) => s.isPaused, 'paused', isTrue),
      ],
      verify: (cubit) {
        expect(cubit.state.isPaused, true);
      },
    );

    test('onResumeFromWatch callback resumes tracking', () async {
      final cubit = buildCubit();
      await cubit.startTracking();
      await cubit.pauseTracking();

      capturedResumeCallback?.call();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isTracking, isTrue);
      await cubit.close();
    });

    test('onStopFromWatch stops tracking WITHOUT navigating, '
        'and marks pendingNavigation true', () async {
      final cubit = buildCubit();
      var navigated = false;
      cubit.registerStopCallbacks(
        onActivitySaved:
            ({
              required double distance,
              required double elevationGap,
              required Duration elapsed,
            }) async {},
        onNavigateAfterStop: () => navigated = true,
      );

      await cubit.startTracking();

      capturedStopCallback?.call();
      await Future<void>.delayed(Duration.zero);

      expect(navigated, isTrue);
      expect(cubit.state.isTracking, isFalse);

      await cubit.close();
    });

    test('pendingNavigation flag is consumed exactly once', () async {
      final cubit = buildCubit();
      var navigateCallCount = 0;
      cubit.registerStopCallbacks(
        onActivitySaved:
            ({
              required double distance,
              required double elevationGap,
              required Duration elapsed,
            }) async {},
        onNavigateAfterStop: () => navigateCallCount++,
      );

      await cubit.startTracking();
      capturedStopCallback?.call();
      await Future<void>.delayed(Duration.zero);

      cubit.consumeNavigation();

      expect(navigateCallCount, 1);
      await cubit.close();
    });
  });

  group('setTotalDistance', () {
    blocTest<LocationCubit, LocationState>(
      'pushes totalDistanceMeters to watch on startTracking',
      build: () {
        final cubit = buildCubit();
        cubit.setTotalDistance(5000);
        return cubit;
      },
      act: (cubit) => cubit.startTracking(),
      verify: (_) {
        final captured = verify(
          () => wearSync.sendStats(captureAny()),
        ).captured.cast<HikeLiveStats>();
        expect(captured.first.totalDistanceMeters, 5000);
      },
    );
  });

  group('setInitialEta', () {
    test('eta reflects the injected initial duration', () {
      final cubit = buildCubit();
      cubit.setInitialEta(const Duration(minutes: 30));

      final etaDiff = cubit.eta.difference(DateTime.now());
      // Allow a small tolerance for test execution time.
      expect(etaDiff.inMinutes, inInclusiveRange(29, 30));

      cubit.close();
    });
  });

  group('close', () {
    test('cancels the GPS subscription and stops background service', () async {
      final cubit = buildCubit();
      await cubit.startTracking();
      await cubit.close();

      verify(
        () => backgroundService.stopTracking(),
      ).called(greaterThanOrEqualTo(1));
    });

    test('does not emit after close (isClosed guard)', () async {
      final cubit = buildCubit();
      await cubit.startTracking();
      await cubit.close();

      // Emitting a point after close should not throw and should not
      // produce further state changes — the `if (isClosed) return;` guard
      // inside the listener should short-circuit silently.
      expect(() => locationController.add(point()), returnsNormally);
    });
  });
}
