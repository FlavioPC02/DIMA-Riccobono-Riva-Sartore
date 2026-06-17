import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/services/watch_notification_service.dart';

import '../mocks/mocks_manual.dart';
import '../test_config.dart';

void main() {
  setUpAll(() {
    setupTest();
  });

  late MockWatchWearSyncService sync;
  late MockFlutterLocalNotificationsPlugin mockPlugin;

  late StreamController<HikeLiveStats> statsController;
  late StreamController<HikeRecordingStatus> statusController;

  late VoidCallback? storedOnOpenNavigation;

  HikeLiveStats stats({
    Duration elapsedTime = const Duration(minutes: 1),
    double distanceMeters = 100,
    double totalDistanceMeters = 1000,
    double elevationGapMeters = 5,
    DateTime? eta,
    bool isOffTrail = false,
    String? offTrailDirection,
  }) {
    return HikeLiveStats(
      elapsedTime: elapsedTime,
      distanceMeters: distanceMeters,
      totalDistanceMeters: totalDistanceMeters,
      elevationGapMeters: elevationGapMeters,
      eta: eta ?? DateTime.now(),
      isOffTrail: isOffTrail,
      offTrailDirection: offTrailDirection,
    );
  }

  setUp(() {
    sync = MockWatchWearSyncService();
    statsController = StreamController<HikeLiveStats>.broadcast();
    statusController = StreamController<HikeRecordingStatus>.broadcast();
    mockPlugin = MockFlutterLocalNotificationsPlugin();

    WatchNotificationService.debugOverridePlugin(mockPlugin);

    when(
      () => mockPlugin.initialize(settings: any(named: 'settings')),
    ).thenAnswer((_) async => true);
    when(
      () => mockPlugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
      ),
    ).thenAnswer((_) async {});

    when(() => sync.initalize()).thenReturn(null);
    when(() => sync.statsStream).thenAnswer((_) => statsController.stream);
    when(() => sync.statusStream).thenAnswer((_) => statusController.stream);
    when(() => sync.shouldOpenNavigation()).thenAnswer((_) async => false);
    when(() => sync.sendPause()).thenAnswer((_) async {});
    when(() => sync.sendResume()).thenAnswer((_) async {});
    when(() => sync.sendStop()).thenAnswer((_) async {});
    when(() => sync.dispose()).thenReturn(null);
    when(() => sync.onOpenNavigation).thenAnswer((_) => storedOnOpenNavigation);
    when(() => sync.onOpenNavigation = any()).thenAnswer((invocation) {
      storedOnOpenNavigation =
          invocation.positionalArguments.first as VoidCallback?;
      return null;
    });
  });

  tearDown(() async {
    await statsController.close();
    await statusController.close();
    WatchNotificationService.debugResetPlugin();
  });

  group('construction', () {
    test('calls initalize on the sync service', () {
      final cubit = WatchLocationCubit(sync);
      verify(() => sync.initalize()).called(1);
      cubit.close();
    });

    test('initial state is WatchLocationState.initial()', () {
      final cubit = WatchLocationCubit(sync);
      expect(cubit.state.isConnecting, isTrue);
      expect(cubit.state.status, HikeRecordingStatus.stopped);
      cubit.close();
    });

    test('checks shouldOpenNavigation on startup and emits a navigation '
        'event if true', () async {
      when(() => sync.shouldOpenNavigation()).thenAnswer((_) async => true);

      final cubit = WatchLocationCubit(sync);
      final events = <void>[];
      final sub = cubit.onNavigateToHike.listen(events.add);

      //allow constructor to complete
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));

      await sub.cancel();
      await cubit.close();
    });

    test('does not emit a navigation event on startup when '
        'shouldOpenNavigation is false', () async {
      final cubit = WatchLocationCubit(sync);
      final events = <void>[];
      final sub = cubit.onNavigateToHike.listen(events.add);

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      await sub.cancel();
      await cubit.close();
    });
  });

  group('stats stream handling', () {
    blocTest<WatchLocationCubit, WatchLocationState>(
      'emits updated stats and clears isConnecting on first stats message',
      build: () => WatchLocationCubit(sync),
      act: (cubit) async {
        statsController.add(stats(distanceMeters: 250));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.isConnecting, isFalse);
        expect(cubit.state.stats.distanceMeters, 250);
      },
    );

    blocTest<WatchLocationCubit, WatchLocationState>(
      'updates lastUpdate timestamp on every stats message',
      build: () => WatchLocationCubit(sync),
      act: (cubit) async {
        final before = DateTime.now();
        statsController.add(stats());
        await Future<void>.delayed(Duration.zero);
        expect(
          cubit.state.lastUpdate.isAfter(
            before.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
      },
    );

    blocTest<WatchLocationCubit, WatchLocationState>(
      'triggers off-trail notification when transitioning from on-trail '
      'to off-trail',
      build: () => WatchLocationCubit(sync),
      act: (cubit) async {
        statsController.add(stats(isOffTrail: false));
        await Future<void>.delayed(Duration.zero);

        statsController.add(
          stats(isOffTrail: true, offTrailDirection: 'Move right'),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.stats.isOffTrail, isTrue);
        expect(cubit.state.stats.offTrailDirection, 'Move right');
      },
    );

    blocTest<WatchLocationCubit, WatchLocationState>(
      'does NOT re-trigger off-trail notification on consecutive off-trail '
      'updates (only on the rising edge)',
      build: () => WatchLocationCubit(sync),
      act: (cubit) async {
        statsController.add(stats(isOffTrail: true, offTrailDirection: 'A'));
        await Future<void>.delayed(Duration.zero);
        statsController.add(stats(isOffTrail: true, offTrailDirection: 'B'));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.stats.offTrailDirection, 'B');
      },
    );

    blocTest<WatchLocationCubit, WatchLocationState>(
      'uses "Unknown direction" fallback when offTrailDirection is null '
      'on the rising edge',
      build: () => WatchLocationCubit(sync),
      act: (cubit) async {
        statsController.add(stats(isOffTrail: true, offTrailDirection: null));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.stats.offTrailDirection, isNull);
      },
    );
  });

  group('status stream handling', () {
    blocTest<WatchLocationCubit, WatchLocationState>(
      'updates status on incoming statusStream event',
      build: () => WatchLocationCubit(sync),
      act: (cubit) async {
        statusController.add(HikeRecordingStatus.paused);
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.status, HikeRecordingStatus.paused);
        expect(cubit.state.isPaused, isTrue);
      },
    );

    blocTest<WatchLocationCubit, WatchLocationState>(
      'resets stats to empty when status becomes stopped',
      build: () => WatchLocationCubit(sync),
      act: (cubit) async {
        statsController.add(stats(distanceMeters: 999));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.stats.distanceMeters, 999);

        statusController.add(HikeRecordingStatus.stopped);
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.status, HikeRecordingStatus.stopped);
        expect(cubit.state.stats, HikeLiveStats.empty());
      },
    );

    blocTest<WatchLocationCubit, WatchLocationState>(
      'does NOT reset stats when status becomes recording or paused',
      build: () => WatchLocationCubit(sync),
      act: (cubit) async {
        statsController.add(stats(distanceMeters: 777));
        await Future<void>.delayed(Duration.zero);

        statusController.add(HikeRecordingStatus.paused);
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.stats.distanceMeters, 777);
      },
    );
  });

  group('navigation stream (onNavigateToHike)', () {
    test('emits when sync.onOpenNavigation callback fires', () async {
      final cubit = WatchLocationCubit(sync);
      final events = <void>[];
      final sub = cubit.onNavigateToHike.listen(events.add);

      storedOnOpenNavigation?.call();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));

      await sub.cancel();
      await cubit.close();
    });

    test(
      'does not throw if onOpenNavigation fires after the cubit is closed',
      () async {
        final cubit = WatchLocationCubit(sync);
        await cubit.close();

        expect(() => sync.onOpenNavigation?.call(), returnsNormally);
      },
    );
  });

  group('pause / resume / stop commands', () {
    blocTest<WatchLocationCubit, WatchLocationState>(
      'pause optimistically emits paused status before awaiting sendPause',
      build: () => WatchLocationCubit(sync),
      act: (cubit) => cubit.pause(),
      verify: (cubit) {
        expect(cubit.state.status, HikeRecordingStatus.paused);
      },
    );

    test('pause calls sync.sendPause', () async {
      final cubit = WatchLocationCubit(sync);
      await cubit.pause();
      verify(() => sync.sendPause()).called(1);
      await cubit.close();
    });

    blocTest<WatchLocationCubit, WatchLocationState>(
      'resume optimistically emits recording status',
      build: () => WatchLocationCubit(sync),
      act: (cubit) => cubit.resume(),
      verify: (cubit) {
        expect(cubit.state.status, HikeRecordingStatus.recording);
      },
    );

    test('resume calls sync.sendResume', () async {
      final cubit = WatchLocationCubit(sync);
      await cubit.resume();
      verify(() => sync.sendResume()).called(1);
      await cubit.close();
    });

    blocTest<WatchLocationCubit, WatchLocationState>(
      'stop optimistically emits stopped status and resets stats to empty',
      build: () => WatchLocationCubit(sync),
      act: (cubit) async {
        statsController.add(stats(distanceMeters: 333));
        await Future<void>.delayed(Duration.zero);
        await cubit.stop();
      },
      verify: (cubit) {
        expect(cubit.state.status, HikeRecordingStatus.stopped);
        expect(cubit.state.stats, HikeLiveStats.empty());
      },
    );

    test('stop calls sync.sendStop', () async {
      final cubit = WatchLocationCubit(sync);
      await cubit.stop();
      verify(() => sync.sendStop()).called(1);
      await cubit.close();
    });
  });

  group('onOffTrailNotification', () {
    test('does not throw when called directly with a message', () {
      final cubit = WatchLocationCubit(sync);
      expect(() => cubit.onOffTrailNotification('Move left'), returnsNormally);
      cubit.close();
    });
  });

  group('close', () {
    test('cancels both subscriptions and disposes the sync service', () async {
      final cubit = WatchLocationCubit(sync);
      await cubit.close();

      verify(() => sync.dispose()).called(1);
    });

    test(
      'does not throw when stats arrive after the cubit is closed',
      () async {
        final cubit = WatchLocationCubit(sync);
        await cubit.close();

        expect(() => statsController.add(stats()), returnsNormally);
      },
    );
  });
}
