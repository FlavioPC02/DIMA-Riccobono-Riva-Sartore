import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/pages/elevation_screen.dart';
import 'package:wear_plus/wear_plus.dart';

import '../mocks/mocks_manual.dart';
import '../test_config.dart';


void main() {
  late MockWatchLocationCubit mockCubit;

  HikeLiveStats stats({double? elevationGapMeters}) => HikeLiveStats(
        elapsedTime: Duration.zero,
        distanceMeters: 0,
        totalDistanceMeters: 0,
        elevationGapMeters: elevationGapMeters,
        eta: DateTime.fromMillisecondsSinceEpoch(0),
        isOffTrail: false,
        offTrailDirection: null,
      );

  WatchLocationState stateWith({double? elevationGapMeters}) {
    return WatchLocationState(
      stats: stats(elevationGapMeters: elevationGapMeters),
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
                child: const ElevationScreen(),
              );
            },
          );
        },
      ),
    );
  }

  group('ElevationScreen', () {
    testWidgets('shows positive elevation gap with a + sign and up arrow',
        (tester) async {
      when(() => mockCubit.state).thenReturn(stateWith(elevationGapMeters: 120));
      whenListen(
        mockCubit,
        Stream.value(stateWith(elevationGapMeters: 120)),
        initialState: stateWith(elevationGapMeters: 120),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('+120 m'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('shows negative elevation gap with a - sign and down arrow',
        (tester) async {
      when(() => mockCubit.state)
          .thenReturn(stateWith(elevationGapMeters: -45));
      whenListen(
        mockCubit,
        Stream.value(stateWith(elevationGapMeters: -45)),
        initialState: stateWith(elevationGapMeters: -45),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('-45 m'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down), findsOneWidget);
    });

    testWidgets('treats null elevationGapMeters as zero', (tester) async {
      when(() => mockCubit.state).thenReturn(stateWith(elevationGapMeters: null));
      whenListen(
        mockCubit,
        Stream.value(stateWith(elevationGapMeters: null)),
        initialState: stateWith(elevationGapMeters: null),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('+0 m'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('shows the "elevation gap" dim label', (tester) async {
      when(() => mockCubit.state).thenReturn(stateWith(elevationGapMeters: 10));
      whenListen(
        mockCubit,
        Stream.value(stateWith(elevationGapMeters: 10)),
        initialState: stateWith(elevationGapMeters: 10),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('elevation gap'), findsOneWidget);
    });

    testWidgets('rebuilds when elevationGapMeters changes via stream',
        (tester) async {
      final controller = StreamController<WatchLocationState>.broadcast();
      addTearDown(controller.close);

      when(() => mockCubit.state).thenReturn(stateWith(elevationGapMeters: 10));
      whenListen(
        mockCubit,
        controller.stream,
        initialState: stateWith(elevationGapMeters: 10),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      expect(find.text('+10 m'), findsOneWidget);

      controller.add(stateWith(elevationGapMeters: 200));
      await tester.pumpAndSettle();

      expect(find.text('+200 m'), findsOneWidget);
      expect(find.text('+10 m'), findsNothing);
    });

    testWidgets('does NOT rebuild when an unrelated field changes', (tester) async {
      final controller = StreamController<WatchLocationState>.broadcast();
      addTearDown(controller.close);

      final initial = stateWith(elevationGapMeters: 10);
      when(() => mockCubit.state).thenReturn(initial);
      whenListen(mockCubit, controller.stream, initialState: initial);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      expect(find.text('+10 m'), findsOneWidget);

      controller.add(WatchLocationState(
        stats: HikeLiveStats(
          elapsedTime: Duration.zero,
          distanceMeters: 999,
          totalDistanceMeters: 0,
          elevationGapMeters: 10,
          eta: DateTime.fromMillisecondsSinceEpoch(0),
          isOffTrail: false,
          offTrailDirection: null,
        ),
        status: HikeRecordingStatus.recording,
        isConnecting: false,
      ));
      await tester.pump();

      expect(find.text('+10 m'), findsOneWidget);
    });
  });
}
