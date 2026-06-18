import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/pages/time_eta_screen.dart';
import 'package:wear_plus/wear_plus.dart';

import '../mocks/mocks_manual.dart';
import '../test_config.dart';


void main() {
  late MockWatchLocationCubit mockCubit;

  HikeLiveStats stats({
    Duration elapsedTime = Duration.zero,
    DateTime? eta,
  }) {
    return HikeLiveStats(
      elapsedTime: elapsedTime,
      distanceMeters: 0,
      totalDistanceMeters: 0,
      elevationGapMeters: 0,
      eta: eta ?? DateTime.fromMillisecondsSinceEpoch(0),
      isOffTrail: false,
      offTrailDirection: null,
    );
  }

  WatchLocationState stateWith({
    Duration elapsedTime = Duration.zero,
    DateTime? eta,
    HikeRecordingStatus status = HikeRecordingStatus.recording,
    DateTime? lastUpdate,
  }) {
    return WatchLocationState(
      stats: stats(elapsedTime: elapsedTime, eta: eta),
      status: status,
      isConnecting: false,
      lastUpdate: lastUpdate ?? DateTime.now(),
    );
  }

  setUpAll(() {
    setupTest();
  });

  setUp(() {
    mockCubit = MockWatchLocationCubit();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: WatchShape(
        builder: (context, shape, child) {
          return AmbientMode(
            builder: (context, mode, child) {
              return BlocProvider<WatchLocationCubit>.value(
                value: mockCubit,
                child: const TimeEtaScreen(),
              );
            },
          );
        },
      ),
    );
  }

  void stubState(WatchLocationState state, {Stream<WatchLocationState>? stream}) {
    when(() => mockCubit.state).thenReturn(state);
    whenListen(mockCubit, stream ?? const Stream<WatchLocationState>.empty(),
        initialState: state);
  }

  //Dispose widget tree to reset timer after each test
  Future<void> disposeWidgetTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  group('TimeEtaScreen', () {
    testWidgets('shows the formatted elapsed time on first build',
        (tester) async {
      stubState(stateWith(
        elapsedTime: const Duration(minutes: 5, seconds: 30),
        status: HikeRecordingStatus.paused, //paused avoids interpolation drift
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(
        find.text(const Duration(minutes: 5, seconds: 30).toCompactLabel()),
        findsOneWidget,
      );

      await disposeWidgetTree(tester);
    });

    testWidgets('shows formatted ETA', (tester) async {
      final eta = DateTime(2026, 6, 17, 18, 0);
      stubState(stateWith(eta: eta, status: HikeRecordingStatus.paused));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text(eta.toCompactLabel()), findsOneWidget);

      await disposeWidgetTree(tester);
    });

    testWidgets('shows the "elapsed" and "eta" dim labels', (tester) async {
      stubState(stateWith(status: HikeRecordingStatus.paused));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('elapsed'), findsOneWidget);
      expect(find.text('eta'), findsOneWidget);

      await disposeWidgetTree(tester);
    });

    testWidgets('when status is paused, the local timer does not advance', (tester) async {
      const fixedElapsed = Duration(minutes: 2);
      stubState(stateWith(
        elapsedTime: fixedElapsed,
        status: HikeRecordingStatus.paused,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      //Simulate 5 timer ticks => elapsedTime should stay the same because we are in paused state
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text(fixedElapsed.toCompactLabel()), findsOneWidget);

      await disposeWidgetTree(tester);
    });

    testWidgets('resets local elapsed to zero when status transitions to stopped', (tester) async {
      final controller = StreamController<WatchLocationState>.broadcast();
      addTearDown(controller.close);

      final recordingState = stateWith(
        elapsedTime: const Duration(minutes: 3),
        status: HikeRecordingStatus.recording,
        lastUpdate: DateTime.now(),
      );
      stubState(recordingState, stream: controller.stream);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      controller.add(stateWith(
        elapsedTime: const Duration(minutes: 3),
        status: HikeRecordingStatus.stopped,
      ));
      await tester.pumpAndSettle();

      expect(find.text(Duration.zero.toCompactLabel()), findsOneWidget);

      await disposeWidgetTree(tester);
    });

    testWidgets('does not throw when the widget is disposed while the periodic timer is active', (tester) async {
      stubState(stateWith(status: HikeRecordingStatus.recording));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await disposeWidgetTree(tester);
      await expectLater(tester.takeException(), isNull);
    });
  });
}
