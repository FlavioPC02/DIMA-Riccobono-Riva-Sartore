import 'package:application/core/models/activity.dart';
import 'package:application/screens/add_activity_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:intl/intl.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:latlong2/latlong.dart';

import '../mocks/mocks_manual.dart';
import '../utils/pump_app.dart';

void main() {
  late MockActivityCubit mockActivityCubit;
  late MockNavigationIndexCubit mockNavigationIndexCubit;

  final dummyActivity = Activity(
    id: 'test_id',
    name: '',
    status: ActivityStatus.planned,
    date: DateTime(2026, 6, 15),
    trailName: 'Sentiero 65',
    distanceKm: 12.5,
    durationMinutes: 180,
    xpEarned: 0,
    notes: [],
    difficulty: ActivityDifficulty.moderate,
    trackedDistance: 0,
    trackedElevationGap: 0,
    trackedTime: Duration.zero,
  );

  setUpAll(() {
    registerFallbackValue(FakeActivity());
    registerFallbackValue(<List<TrailPoint>>[]);
  });

  setUp(() {
    mockActivityCubit = MockActivityCubit();

    when(
      () => mockActivityCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockActivityCubit.state).thenReturn([]);

    when(
      () => mockActivityCubit.addPlannedActivity(any(), any()),
    ).thenAnswer((_) async {});
    mockNavigationIndexCubit = MockNavigationIndexCubit();
    
    when(() => mockActivityCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockActivityCubit.state).thenReturn([]);
    when(() => mockActivityCubit.addActivity(any())).thenAnswer((_) async => '');

    when(() => mockNavigationIndexCubit.state).thenReturn(0);
    when(() => mockNavigationIndexCubit.stream).thenAnswer((_) => Stream<int>.value(0));
  });

  Widget createWidgetUnderTest() {
    return pumpApp(
      activityCubit: mockActivityCubit,
      navigationIndexCubit: mockNavigationIndexCubit,
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddActivityPage(
                        activity: dummyActivity,
                        trailSegments: const [
                          [LatLng(45.1, 9.1), LatLng(45.2, 9.2)],
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open Page'),
              ),
            ),
          );
        },
      ),
    );
  }

  group('AddActivityPage Widget Tests', () {
    testWidgets('renders correctly with initial data', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Open Page'));
      await tester.pumpAndSettle();

      expect(find.text('New Planned Hike'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      expect(find.text('ACTIVITY'), findsOneWidget);
      expect(find.text('DATE'), findsOneWidget);
      expect(find.text('DETAILS'), findsOneWidget);

      expect(find.text('Sentiero 65'), findsOneWidget);
      expect(find.text('12.5 km'), findsOneWidget);
      expect(find.text('3h'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);

      final expectedDate = DateFormat('dd/MM/yyyy').format(dummyActivity.date);
      expect(find.text(expectedDate), findsOneWidget);
    });

    testWidgets('shows validation error if name is empty', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Open Page'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Required'), findsOneWidget);

      verifyNever(() => mockActivityCubit.addPlannedActivity(any(), any()));
    });

    testWidgets('opens DatePicker and updates date on selection', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Open Page'));
      await tester.pumpAndSettle();

      final initialDateStr = DateFormat(
        'dd/MM/yyyy',
      ).format(dummyActivity.date);
      expect(find.text(initialDateStr), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final updatedDateStr = DateFormat(
        'dd/MM/yyyy',
      ).format(DateTime(2026, 6, 20));
      expect(find.text(updatedDateStr), findsOneWidget);
    });

    testWidgets('saves valid form and pops navigation', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Open Page'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.ancestor(
          of: find.text('Name'),
          matching: find.byType(TextFormField),
        ),
        'My Planned Hike',
      );

      await tester.tap(find.text('Save'));
      await tester.pump();

      verify(
        () => mockActivityCubit.addPlannedActivity(
          any(
            that: isA<Activity>()
                .having((a) => a.name, 'name', 'My Planned Hike')
                .having((a) => a.status, 'status', ActivityStatus.planned)
                .having((a) => a.trailName, 'trailName', 'Sentiero 65')
                .having((a) => a.distanceKm, 'distanceKm', 12.5),
          ),
          any(
            that: isA<List<List<TrailPoint>>>()
                .having((segments) => segments.length, 'segments', 1)
                .having((segments) => segments.first.length, 'points', 2)
                .having(
                  (segments) => segments.first.first.lat,
                  'first latitude',
                  45.1,
                )
                .having(
                  (segments) => segments.first.first.lng,
                  'first longitude',
                  9.1,
                ),
          ),
        ),
      ).called(1);

      await tester.pumpAndSettle();

      expect(find.byType(AddActivityPage), findsNothing);
      expect(find.text('Open Page'), findsOneWidget);
    });
  });
}
