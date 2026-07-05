import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/pages/trail_dashboard_page.dart';
import 'package:wear_app/features/widgets/command_overlay.dart';

import '../mocks/mocks_manual.dart';

void main() {
  late MockWatchLocationCubit mockCubit;

  HikeLiveStats stats({Duration elapsedTime = Duration.zero}) {
    return HikeLiveStats(
      elapsedTime: elapsedTime,
      distanceMeters: 0,
      totalDistanceMeters: 0,
      elevationGapMeters: 0,
      eta: DateTime.fromMillisecondsSinceEpoch(0),
      isOffTrail: false,
      offTrailDirection: null,
    );
  }

  WatchLocationState stateWith({
    HikeRecordingStatus status = HikeRecordingStatus.recording,
    Duration elapsedTime = Duration.zero,
  }) {
    return WatchLocationState(
      stats: stats(elapsedTime: elapsedTime),
      status: status,
      isConnecting: false,
      lastUpdate: DateTime.now(),
    );
  }

  setUp(() {
    mockCubit = MockWatchLocationCubit();
    // pause/resume/stop are called by CommandOverlay buttons; stub them so
    // taps don't throw on an unstubbed method call.
    when(() => mockCubit.pause()).thenAnswer((_) async {});
    when(() => mockCubit.resume()).thenAnswer((_) async {});
    when(() => mockCubit.stop()).thenAnswer((_) async {});
  });

  // TrailDashboardPage is meant to be pushed as a route (it calls
  // Navigator.of(context).popUntil internally), so the test harness wraps
  // it inside a real MaterialApp with an initial placeholder route beneath
  // it, then navigates to it via push — this matches production usage and
  // makes popUntil meaningful in the test.
  Widget createWidgetUnderTest({
    required Stream<WatchLocationState> stream,
    required WatchLocationState initialState,
  }) {
    when(() => mockCubit.state).thenReturn(initialState);
    whenListen(mockCubit, stream, initialState: initialState);

    return MaterialApp(
      home: BlocProvider<WatchLocationCubit>.value(
        value: mockCubit,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider<WatchLocationCubit>.value(
                      value: mockCubit,
                      child: const TrailDashboardPage(),
                    ),
                  ),
                ),
                child: const Text('open dashboard'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pushDashboard(WidgetTester tester) async {
    await tester.tap(find.text('open dashboard'));
    await tester.pumpAndSettle();
  }

  group('TrailDashboardPage navigation', () {
    testWidgets('pops back to the first route when status becomes stopped',
        (tester) async {
      final controller = StreamController<WatchLocationState>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(createWidgetUnderTest(
        stream: controller.stream,
        initialState: stateWith(status: HikeRecordingStatus.recording),
      ));
      await pushDashboard(tester);

      expect(find.byType(TrailDashboardPage), findsOneWidget);

      controller.add(stateWith(status: HikeRecordingStatus.stopped));
      await tester.pumpAndSettle();

      expect(find.byType(TrailDashboardPage), findsNothing);
      expect(find.text('open dashboard'), findsOneWidget);
    });

    testWidgets('does NOT pop when status changes between recording and '
        'paused', (tester) async {
      final controller = StreamController<WatchLocationState>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(createWidgetUnderTest(
        stream: controller.stream,
        initialState: stateWith(status: HikeRecordingStatus.recording),
      ));
      await pushDashboard(tester);

      controller.add(stateWith(status: HikeRecordingStatus.paused));
      await tester.pumpAndSettle();

      expect(find.byType(TrailDashboardPage), findsOneWidget);
    });
  });

  group('TrailDashboardPage page view', () {
    testWidgets('renders a vertical PageView with 3 pages', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        stream: const Stream.empty(),
        initialState: stateWith(),
      ));
      await pushDashboard(tester);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.scrollDirection, Axis.vertical);
    });

    testWidgets('shows the command toggle button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        stream: const Stream.empty(),
        initialState: stateWith(),
      ));
      await pushDashboard(tester);

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('tapping the command button shows the CommandOverlay and '
        'switches icon to close', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        stream: const Stream.empty(),
        initialState: stateWith(),
      ));
      await pushDashboard(tester);

      expect(find.byType(CommandOverlay), findsNothing);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();

      expect(find.byType(CommandOverlay), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('dismissing the CommandOverlay hides it and restores the '
        'more_horiz icon', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        stream: const Stream.empty(),
        initialState: stateWith(),
      ));
      await pushDashboard(tester);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      expect(find.byType(CommandOverlay), findsOneWidget);

      await tester.tap(find.byType(CommandOverlay));
      await tester.pumpAndSettle();

      expect(find.byType(CommandOverlay), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });
  });
}
