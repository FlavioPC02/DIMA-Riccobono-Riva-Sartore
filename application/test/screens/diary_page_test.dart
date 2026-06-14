import 'package:application/core/models/activity.dart';
import 'package:application/screens/activity_detail_page.dart';
import 'package:application/screens/diary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/pump_app.dart';

void main() {
  late MockActivityCubit mockActivityCubit;

  setUpAll(() {
    registerFallbackValue(FakeActivity());
  });

  setUp(() {
    mockActivityCubit = MockActivityCubit();
    
    when(() => mockActivityCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockActivityCubit.state).thenReturn([]);
  });

  final completedActivity = Activity(
    id: '1',
    name: 'Monte Baldo Completed',
    status: ActivityStatus.completed,
    date: DateTime(2026, 6, 10),
    trailName: 'Sentiero 1',
    distanceKm: 10,
    durationMinutes: 120,
    xpEarned: 150,
    notes: 'Bella vista',
    difficulty: ActivityDifficulty.moderate,
    trackedDistance: 10,
    trackedElevationGap: 500,
    trackedTime: const Duration(hours: 2),
  );

  final plannedActivity = Activity(
    id: '2',
    name: 'Garda Planned',
    status: ActivityStatus.planned,
    date: DateTime(2026, 6, 20),
    trailName: 'Sentiero 2',
    distanceKm: 5,
    durationMinutes: 60,
    xpEarned: 0,
    notes: '',
    difficulty: ActivityDifficulty.easy,
    trackedDistance: 0,
    trackedElevationGap: 0,
    trackedTime: Duration.zero,
  );

  Widget createWidgetUnderTest() {
    return pumpApp(
      activityCubit: mockActivityCubit,
      child: const DiaryPage(),
    );
  }

  group('DiaryPage Widget Tests', () {
    testWidgets('renders correctly with empty activities', (tester) async {
      when(() => mockActivityCubit.state).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Diary'), findsWidgets);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Planned'), findsOneWidget);

      expect(find.text('No completed hikes yet.\nStart exploring!'), findsOneWidget);
      expect(find.byIcon(Icons.terrain), findsOneWidget);

      await tester.tap(find.text('Planned'));
      await tester.pumpAndSettle();

      expect(find.text('No planned hikes yet.\nSchedule your next adventure!'), findsOneWidget);
      expect(find.byIcon(Icons.event_note), findsOneWidget);
    });

    testWidgets('renders activities in correct tabs', (tester) async {
      when(() => mockActivityCubit.state).thenReturn([completedActivity, plannedActivity]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Monte Baldo Completed'), findsOneWidget);
      expect(find.text('10/06/2026'), findsOneWidget);
      expect(find.byIcon(Icons.hiking), findsOneWidget);

      expect(find.text('Garda Planned'), findsNothing);

      await tester.tap(find.text('Planned'));
      await tester.pumpAndSettle();

      expect(find.text('Garda Planned'), findsOneWidget);
      expect(find.text('20/06/2026'), findsOneWidget);

      expect(find.text('Monte Baldo Completed'), findsNothing);
    });

    testWidgets('tapping an activity opens ActivityDetailPage', (tester) async {
      when(() => mockActivityCubit.state).thenReturn([completedActivity]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Monte Baldo Completed'));
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ActivityDetailPage), findsOneWidget);
    });
  });
}