import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/widgets/command_overlay.dart';

import '../mocks/mocks_manual.dart';

void main() {
  late MockWatchLocationCubit mockCubit;
  late int dismissCallCount;

  HikeLiveStats stats() => HikeLiveStats(
        elapsedTime: Duration.zero,
        distanceMeters: 0,
        totalDistanceMeters: 0,
        elevationGapMeters: 0,
        eta: DateTime.fromMillisecondsSinceEpoch(0),
        isOffTrail: false,
        offTrailDirection: null,
      );

  WatchLocationState stateWith({
    HikeRecordingStatus status = HikeRecordingStatus.recording,
  }) {
    return WatchLocationState(
      stats: stats(),
      status: status,
      isConnecting: false,
      lastUpdate: DateTime.now(),
    );
  }

  setUp(() {
    mockCubit = MockWatchLocationCubit();
    dismissCallCount = 0;

    when(() => mockCubit.pause()).thenAnswer((_) async {});
    when(() => mockCubit.resume()).thenAnswer((_) async {});
    when(() => mockCubit.stop()).thenAnswer((_) async {});
  });

  void onDismiss() => dismissCallCount++;

  Widget createWidgetUnderTest({
    required WatchLocationState initialState,
    bool isRound = true,
  }) {
    when(() => mockCubit.state).thenReturn(initialState);
    whenListen(
      mockCubit,
      Stream<WatchLocationState>.empty(),
      initialState: initialState,
    );

    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<WatchLocationCubit>.value(
          value: mockCubit,
          child: CommandOverlay(
            isRound: isRound,
            onDismiss: onDismiss,
          ),
        ),
      ),
    );
  }

  group('CommandOverlay rendering', () {
    testWidgets('shows Pause and Stop buttons when recording',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(status: HikeRecordingStatus.recording),
      ));

      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('shows Resume instead of Pause when paused', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(status: HikeRecordingStatus.paused),
      ));

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('Stop button is shown regardless of paused/recording status',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(status: HikeRecordingStatus.paused),
      ));

      expect(find.text('Stop'), findsOneWidget);
    });

    testWidgets('renders a semi-transparent black backdrop', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(),
      ));

      final backdropFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.color != null &&
            (widget.color!.a - 0.75).abs() < 0.01,
      );

      expect(backdropFinder, findsOneWidget);

      final container = tester.widget<Container>(backdropFinder);
      expect(container.color!.a, closeTo(0.75, 0.01));
    });
  });

  group('CommandOverlay pause/resume interaction', () {
    testWidgets('tapping Pause calls cubit.pause() and dismisses the overlay',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(status: HikeRecordingStatus.recording),
      ));

      await tester.tap(find.text('Pause'));
      await tester.pump();

      verify(() => mockCubit.pause()).called(1);
      verifyNever(() => mockCubit.resume());
      expect(dismissCallCount, 1);
    });

    testWidgets('tapping Resume calls cubit.resume() and dismisses the '
        'overlay', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(status: HikeRecordingStatus.paused),
      ));

      await tester.tap(find.text('Resume'));
      await tester.pump();

      verify(() => mockCubit.resume()).called(1);
      verifyNever(() => mockCubit.pause());
      expect(dismissCallCount, 1);
    });
  });

  group('CommandOverlay stop confirmation flow', () {
    testWidgets('tapping Stop opens a confirmation dialog', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(),
      ));

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      expect(find.text('Stop hike?'), findsOneWidget);
      verifyNever(() => mockCubit.stop());
      //onDismiss not called yet
      expect(dismissCallCount, 0);
    });

    testWidgets('confirmation dialog shows Cancel and Stop actions',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(),
      ));

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Stop'), findsNWidgets(2));
    });

    testWidgets('tapping Cancel closes the dialog without stopping',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(),
      ));

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Stop hike?'), findsNothing);
      verifyNever(() => mockCubit.stop());
      expect(dismissCallCount, 0);
    });

    testWidgets('confirming Stop in the dialog calls cubit.stop(), closes '
        'the dialog, and dismisses the overlay', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(),
      ));

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stop').last);
      await tester.pumpAndSettle();

      expect(find.text('Stop hike?'), findsNothing);
      verify(() => mockCubit.stop()).called(1);
      expect(dismissCallCount, 1);
    });

    testWidgets('dialog stop action calls Navigator.pop before cubit.stop()', (tester) async {
      when(() => mockCubit.stop()).thenThrow(Exception('boom'));

      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(),
      ));

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stop').last);

      final error = tester.takeException();
      expect(error, isA<Exception>());
      expect(error.toString(), contains('boom'));

      await tester.pumpAndSettle();

      expect(find.text('Stop hike?'), findsNothing);
    });
  });

  group('CommandOverlay backdrop dismissal', () {
    testWidgets('tapping the backdrop outside the buttons calls onDismiss',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(),
      ));

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();

      expect(dismissCallCount, 1);
    });

    testWidgets('tapping directly on a button does NOT also trigger the '
        'backdrop dismissal a second time', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        initialState: stateWith(status: HikeRecordingStatus.recording),
      ));

      await tester.tap(find.text('Pause'));
      await tester.pump();

      expect(dismissCallCount, 1);
    });
  });

  group('CommandOverlay buildWhen optimization', () {
    testWidgets('does not rebuild the button labels when an unrelated '
        'field changes', (tester) async {
      final controller = StreamController<WatchLocationState>.broadcast();
      addTearDown(controller.close);

      final initial = stateWith(status: HikeRecordingStatus.recording);
      when(() => mockCubit.state).thenReturn(initial);
      whenListen(mockCubit, controller.stream, initialState: initial);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BlocProvider<WatchLocationCubit>.value(
            value: mockCubit,
            child: CommandOverlay(isRound: true, onDismiss: onDismiss),
          ),
        ),
      ));

      expect(find.text('Pause'), findsOneWidget);

      controller.add(WatchLocationState(
        stats: HikeLiveStats(
          elapsedTime: const Duration(minutes: 5),
          distanceMeters: 100,
          totalDistanceMeters: 0,
          elevationGapMeters: 0,
          eta: DateTime.fromMillisecondsSinceEpoch(0),
          isOffTrail: false,
          offTrailDirection: null,
        ),
        status: HikeRecordingStatus.recording,
        isConnecting: false,
      ));
      await tester.pump();

      expect(find.text('Pause'), findsOneWidget);
    });
  });
}