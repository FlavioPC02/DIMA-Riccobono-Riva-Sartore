import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/pages/distance_screen.dart';
import 'package:wear_plus/wear_plus.dart';

import '../mocks/mocks_manual.dart';
import '../test_config.dart';


void main() {
  late MockWatchLocationCubit mockCubit;

  HikeLiveStats stats({
    double distanceMeters = 0,
    double totalDistanceMeters = 0,
  }) {
    return HikeLiveStats(
      elapsedTime: Duration.zero,
      distanceMeters: distanceMeters,
      totalDistanceMeters: totalDistanceMeters,
      elevationGapMeters: 0,
      eta: DateTime.fromMillisecondsSinceEpoch(0),
      isOffTrail: false,
      offTrailDirection: null,
    );
  }

  WatchLocationState stateWith({
    double distanceMeters = 0,
    double totalDistanceMeters = 0,
  }) {
    return WatchLocationState(
      stats: stats(
        distanceMeters: distanceMeters,
        totalDistanceMeters: totalDistanceMeters,
      ),
      status: HikeRecordingStatus.recording,
      isConnecting: false,
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
                child: const DistanceScreen(),
              );
            },
          );
        },
      ),
    );
  }

  void stubState(WatchLocationState state, {Stream<WatchLocationState>? stream}) {
    when(() => mockCubit.state).thenReturn(state);
    whenListen(mockCubit, stream ?? Stream.value(state), initialState: state);
  }

  group('DistanceScreen', () {
    testWidgets('shows distance in meters when under 1000m', (tester) async {
      stubState(stateWith(distanceMeters: 450, totalDistanceMeters: 1000));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('450 m'), findsOneWidget);
    });

    testWidgets('shows distance in km when 1000m or more',
        (tester) async {
      stubState(stateWith(distanceMeters: 2345, totalDistanceMeters: 5000));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('2.35 km'), findsOneWidget);
    });

    testWidgets('shows "of <totalLabel>" when totalDistanceMeters > 0',
        (tester) async {
      stubState(stateWith(distanceMeters: 500, totalDistanceMeters: 5000));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('of 5.00 km'), findsOneWidget);
    });

    testWidgets('hides the "of <totalLabel>" line when totalDistanceMeters is 0', (tester) async {
      stubState(stateWith(distanceMeters: 500, totalDistanceMeters: 0));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.textContaining('of '), findsNothing);
    });

    testWidgets('shows 0% progress when totalDistanceMeters is 0', (tester) async {
      stubState(stateWith(distanceMeters: 500, totalDistanceMeters: 0));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('shows correct rounded percentage for partial progress',
        (tester) async {
      stubState(stateWith(distanceMeters: 2500, totalDistanceMeters: 5000));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('clamps progress at 100% when distance exceeds total',
        (tester) async {
      stubState(stateWith(distanceMeters: 6000, totalDistanceMeters: 5000));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('shows the "covered" dim label', (tester) async {
      stubState(stateWith(distanceMeters: 100, totalDistanceMeters: 1000));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('covered'), findsOneWidget);
    });

    testWidgets('renders progress ring', (tester) async {
      stubState(stateWith(distanceMeters: 100, totalDistanceMeters: 1000));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('rebuilds when distanceMeters changes via stream',
        (tester) async {
      final controller = StreamController<WatchLocationState>.broadcast();
      addTearDown(controller.close);

      final initial = stateWith(distanceMeters: 100, totalDistanceMeters: 1000);
      stubState(initial, stream: controller.stream);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      expect(find.text('100 m'), findsOneWidget);

      controller.add(stateWith(distanceMeters: 800, totalDistanceMeters: 1000));
      await tester.pumpAndSettle();

      expect(find.text('800 m'), findsOneWidget);
      expect(find.text('100 m'), findsNothing);
    });
  });
}
