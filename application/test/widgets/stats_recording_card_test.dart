//import 'package:application/core/cubit/location_cubit.dart';
//import 'package:application/widgets/stats_recording_card.dart';
//import 'package:flutter/material.dart';
//import 'package:flutter_test/flutter_test.dart';
//import 'package:hike_core/hike_core.dart';
//import 'package:mocktail/mocktail.dart';
//
//class MockCallback extends Mock {
//  void call();
//}
//
//void main() {
//  // ── Shared fixtures ────────────────────────────────────────────────────
//
//  late MockCallback onToggleRecording;
//  late MockCallback onStopRecording;
//
//  setUp(() {
//    onToggleRecording = MockCallback();
//    onStopRecording = MockCallback();
//  });
//
//  LocationState buildStats({
//    DateTime? eta,
//    double distance = 1200,
//    double? elevationGap = 45,
//  }) {
//    return LocationState.tracking(
//      points: const [],
//      current: null,
//      distance: distance,
//      elevationGap: elevationGap,
//      totalAscent: 0,
//      totalDescent: 0,
//      eta: eta,
//    );
//  }
//
//  Widget buildTestable({
//    String trailName = 'Monte Bianco Trail',
//    Duration elapsedTime = const Duration(minutes: 5, seconds: 30),
//    bool isRecording = true,
//    LocationState? stats,
//  }) {
//    return MaterialApp(
//      home: Scaffold(
//        body: SizedBox(
//          height: 800,
//          child: StatsRecordingCard(
//            trailName: trailName,
//            elapsedTime: elapsedTime,
//            isRecording: isRecording,
//            onToggleRecording: onToggleRecording.call,
//            onStopRecording: onStopRecording.call,
//            stats: stats ?? buildStats(),
//          ),
//        ),
//      ),
//    );
//  }
//
//  group('collapsed state (initial render)', () {
//    testWidgets('renders the trail name', (tester) async {
//      await tester.pumpWidget(buildTestable(trailName: 'Sentiero del Sole'));
//
//      expect(find.text('Sentiero del Sole'), findsOneWidget);
//    });
//
//    testWidgets('does not show Time/ETA/Distance/Elevation details '
//        'when collapsed', (tester) async {
//      await tester.pumpWidget(buildTestable());
//
//      expect(find.text('Time'), findsNothing);
//      expect(find.text('ETA'), findsNothing);
//      expect(find.text('Distance'), findsNothing);
//      expect(find.text('Elevation Gap'), findsNothing);
//    });
//
//    testWidgets('does not show Pause/Stop buttons when collapsed', (
//      tester,
//    ) async {
//      await tester.pumpWidget(buildTestable());
//
//      expect(find.widgetWithText(ElevatedButton, 'Pause'), findsNothing);
//      expect(find.widgetWithText(ElevatedButton, 'Stop'), findsNothing);
//    });
//
//    testWidgets('renders without error and shows a DraggableScrollableSheet', (
//      tester,
//    ) async {
//      await tester.pumpWidget(buildTestable());
//
//      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
//    });
//  });
//
//  group('expanded state (details revealed)', () {
//    Future<void> expandSheet(WidgetTester tester) async {
//      await tester.pumpAndSettle();
//
//      await tester.fling(
//        find.byType(StatsRecordingCard),
//        const Offset(0, -600),
//        1200,
//      );
//
//      await tester.pumpAndSettle();
//    }
//
//    testWidgets('reveals Time, ETA, Distance, and Elevation Gap labels '
//        'after dragging the sheet up', (tester) async {
//      await tester.pumpWidget(
//        buildTestable(
//          elapsedTime: const Duration(minutes: 12, seconds: 5),
//          stats: buildStats(eta: DateTime(2026, 6, 17, 14, 30)),
//        ),
//      );
//
//      await expandSheet(tester);
//
//      expect(find.text('Time'), findsOneWidget);
//      expect(find.text('ETA'), findsOneWidget);
//      expect(find.text('Distance'), findsOneWidget);
//      expect(find.text('Elevation Gap'), findsOneWidget);
//    });
//
//    testWidgets('shows formatted elapsed time via toCompactLabel()', (
//      tester,
//    ) async {
//      const elapsed = Duration(minutes: 7, seconds: 42);
//      await tester.pumpWidget(buildTestable(elapsedTime: elapsed));
//
//      await expandSheet(tester);
//
//      expect(find.text(elapsed.toCompactLabel()), findsOneWidget);
//    });
//
//    testWidgets('shows "--" for ETA when stats.eta is null', (tester) async {
//      await tester.pumpWidget(buildTestable(stats: buildStats(eta: null)));
//
//      await expandSheet(tester);
//
//      expect(find.text('--'), findsOneWidget);
//    });
//
//    testWidgets('shows formatted ETA via toCompactLabel() when present', (
//      tester,
//    ) async {
//      final eta = DateTime(2026, 6, 17, 16, 0);
//      await tester.pumpWidget(buildTestable(stats: buildStats(eta: eta)));
//
//      await expandSheet(tester);
//
//      expect(find.text(eta.toCompactLabel()), findsOneWidget);
//    });
//
//    testWidgets('shows distance via getDistanceLabel()', (tester) async {
//      final stats = buildStats(distance: 3400);
//      await tester.pumpWidget(buildTestable(stats: stats));
//
//      await expandSheet(tester);
//
//      expect(find.text(stats.getDistanceLabel()), findsOneWidget);
//    });
//
//    testWidgets('shows elevation gap via getElevationGapLabel()', (
//      tester,
//    ) async {
//      final stats = buildStats(elevationGap: 120);
//      await tester.pumpWidget(buildTestable(stats: stats));
//
//      await expandSheet(tester);
//
//      expect(find.text(stats.getElevationGapLabel()), findsOneWidget);
//    });
//
//    testWidgets('reveals Pause and Stop buttons when isRecording is true', (
//      tester,
//    ) async {
//      await tester.pumpWidget(buildTestable(isRecording: true));
//
//      await expandSheet(tester);
//
//      expect(find.widgetWithText(ElevatedButton, 'Pause'), findsOneWidget);
//      expect(find.widgetWithText(ElevatedButton, 'Stop'), findsOneWidget);
//      expect(find.byIcon(Icons.pause), findsOneWidget);
//      expect(find.byIcon(Icons.stop), findsOneWidget);
//    });
//
//    testWidgets('shows Resume button instead of Pause when isRecording is '
//        'false', (tester) async {
//      await tester.pumpWidget(buildTestable(isRecording: false));
//
//      await expandSheet(tester);
//
//      expect(find.widgetWithText(ElevatedButton, 'Resume'), findsOneWidget);
//      expect(find.widgetWithText(ElevatedButton, 'Pause'), findsNothing);
//      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
//    });
//  });
//
//  group('button interactions', () {
//    Future<void> expandSheet(WidgetTester tester) async {
//      final dragHandle = find.byType(StatsRecordingCard);
//      await tester.drag(dragHandle, const Offset(0, -400));
//      await tester.pumpAndSettle();
//    }
//
//    testWidgets('tapping Pause invokes onToggleRecording', (tester) async {
//      await tester.pumpWidget(buildTestable(isRecording: true));
//      await expandSheet(tester);
//
//      await tester.tap(find.widgetWithText(ElevatedButton, 'Pause'));
//      await tester.pump();
//
//      verify(() => onToggleRecording()).called(1);
//    });
//
//    testWidgets('tapping Resume invokes onToggleRecording', (tester) async {
//      await tester.pumpWidget(buildTestable(isRecording: false));
//      await expandSheet(tester);
//
//      await tester.tap(find.widgetWithText(ElevatedButton, 'Resume'));
//      await tester.pump();
//
//      verify(() => onToggleRecording()).called(1);
//    });
//
//    testWidgets('tapping Stop invokes onStopRecording', (tester) async {
//      await tester.pumpWidget(buildTestable());
//      await expandSheet(tester);
//
//      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop'));
//      await tester.pump();
//
//      verify(() => onStopRecording()).called(1);
//    });
//
//    testWidgets('onStopRecording is never called from a Pause tap', (
//      tester,
//    ) async {
//      await tester.pumpWidget(buildTestable(isRecording: true));
//      await expandSheet(tester);
//
//      await tester.tap(find.widgetWithText(ElevatedButton, 'Pause'));
//      await tester.pump();
//
//      verifyNever(() => onStopRecording());
//    });
//  });
//
//  group('collapsedSheetHeight (static helper)', () {
//    testWidgets('returns a height that grows with longer trail names', (
//      tester,
//    ) async {
//      late double shortHeight;
//      late double longHeight;
//
//      await tester.pumpWidget(
//        MaterialApp(
//          home: Builder(
//            builder: (context) {
//              shortHeight = StatsRecordingCard.collapsedSheetHeight(
//                context,
//                'A',
//              );
//              longHeight = StatsRecordingCard.collapsedSheetHeight(
//                context,
//                'A very long trail name that will definitely wrap across '
//                'multiple lines on a typical phone screen width',
//              );
//              return const SizedBox();
//            },
//          ),
//        ),
//      );
//
//      expect(longHeight, greaterThan(shortHeight));
//    });
//
//    testWidgets('returns a positive height for an empty trail name', (
//      tester,
//    ) async {
//      late double height;
//
//      await tester.pumpWidget(
//        MaterialApp(
//          home: Builder(
//            builder: (context) {
//              height = StatsRecordingCard.collapsedSheetHeight(context, '');
//              return const SizedBox();
//            },
//          ),
//        ),
//      );
//
//      expect(height, greaterThanOrEqualTo(32));
//    });
//  });
//
//  group('didChangeDependencies / collapsed size recalculation', () {
//    testWidgets('updating trailName via setState-driven rebuild does not throw '
//        'and keeps the sheet usable', (tester) async {
//      String trailName = 'Short';
//
//      await tester.pumpWidget(
//        StatefulBuilder(
//          builder: (context, setState) {
//            return MaterialApp(
//              home: Scaffold(
//                body: Column(
//                  children: [
//                    ElevatedButton(
//                      onPressed: () => setState(
//                        () => trailName =
//                            'A Much Longer Trail '
//                            'Name That Changes The Collapsed Height',
//                      ),
//                      child: const Text('change'),
//                    ),
//                    Expanded(
//                      child: StatsRecordingCard(
//                        trailName: trailName,
//                        elapsedTime: Duration.zero,
//                        isRecording: true,
//                        onToggleRecording: onToggleRecording.call,
//                        onStopRecording: onStopRecording.call,
//                        stats: buildStats(),
//                      ),
//                    ),
//                  ],
//                ),
//              ),
//            );
//          },
//        ),
//      );
//
//      expect(find.text('Short'), findsOneWidget);
//
//      await tester.tap(find.text('change'));
//      await tester.pumpAndSettle();
//
//      expect(
//        find.text(
//          'A Much Longer Trail Name That Changes The Collapsed '
//          'Height',
//        ),
//        findsOneWidget,
//      );
//    });
//  });
//
//  group('widget lifecycle', () {
//    testWidgets('builds without throwing when stats has all-zero values', (
//      tester,
//    ) async {
//      await tester.pumpWidget(
//        buildTestable(
//          stats: buildStats(distance: 0, elevationGap: 0, eta: null),
//          elapsedTime: Duration.zero,
//        ),
//      );
//
//      expect(find.byType(StatsRecordingCard), findsOneWidget);
//    });
//
//    testWidgets('builds without throwing when elevationGap is null', (
//      tester,
//    ) async {
//      await tester.pumpWidget(
//        buildTestable(stats: buildStats(elevationGap: null)),
//      );
//
//      expect(find.byType(StatsRecordingCard), findsOneWidget);
//    });
//
//    testWidgets('rebuilds cleanly when isRecording toggles', (tester) async {
//      bool isRecording = true;
//
//      await tester.pumpWidget(
//        StatefulBuilder(
//          builder: (context, setState) {
//            return MaterialApp(
//              home: Scaffold(
//                body: Column(
//                  children: [
//                    ElevatedButton(
//                      onPressed: () =>
//                          setState(() => isRecording = !isRecording),
//                      child: const Text('toggle'),
//                    ),
//                    Expanded(
//                      child: SizedBox(
//                        height: 800,
//                        child: StatsRecordingCard(
//                          trailName: 'Trail',
//                          elapsedTime: Duration.zero,
//                          isRecording: isRecording,
//                          onToggleRecording: onToggleRecording.call,
//                          onStopRecording: onStopRecording.call,
//                          stats: buildStats(),
//                        ),
//                      ),
//                    ),
//                  ],
//                ),
//              ),
//            );
//          },
//        ),
//      );
//
//      await tester.drag(find.byType(StatsRecordingCard), const Offset(0, -400));
//      await tester.pumpAndSettle();
//
//      expect(find.widgetWithText(ElevatedButton, 'Pause'), findsOneWidget);
//
//      await tester.tap(find.text('toggle'));
//      await tester.pumpAndSettle();
//
//      expect(find.widgetWithText(ElevatedButton, 'Resume'), findsOneWidget);
//    });
//  });
//}
//