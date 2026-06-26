import 'dart:io';
import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/models/profile.dart';
import 'package:application/services/phone_wear_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/screens/trail_details_screen.dart';
import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';
import '../utils/trails_details_screen_test_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late MockFavoriteTrailStore mockFavoriteTrailStore;
  late MockActivityCubit mockActivityCubit;
  late MockProfileCubit mockProfileCubit;

  final trailMap = {'id': 12345, 'name': 'Sentiero Test', 'subTrails': []};

  final getIt = GetIt.instance;

  setUpAll(() {
    const envString = '''MAPBOX_ACCESS_TOKEN=test_token_123''';
    dotenv.loadFromString(envString: envString);

    HttpOverrides.global = FakeHttpOverrides();
    if (!getIt.isRegistered<LocationCubit>()) {
      getIt.registerSingleton<LocationCubit>(MockLocationCubit());
    }
    if (!getIt.isRegistered<PhoneWearSyncService>()) {
      getIt.registerSingleton<PhoneWearSyncService>(MockPhoneWearSyncService());
    }
  });

  setUp(() {
    setupTest();
    FakeHttpOverrides.shouldFailConnections = false;
    FakeHttpOverrides.emptyOverpassRelation = false;
    FakeHttpOverrides.emptyWeatherForecast = false;
    FakeHttpOverrides.emptyElevationData = false;
    FakeHttpOverrides.customTags = null;
    FakeHttpOverrides.customWeatherCodes = null;

    final mockLocationCubit = getIt<LocationCubit>();
    final mockPhoneWearSyncService = getIt<PhoneWearSyncService>();
    mockFavoriteTrailStore = MockFavoriteTrailStore();
    mockActivityCubit = MockActivityCubit();
    mockProfileCubit = MockProfileCubit();

    when(() => mockLocationCubit.startTracking()).thenAnswer((_) async {});
    when(() => mockLocationCubit.stopAndSave()).thenAnswer((_) async {});
    when(() => mockLocationCubit.close()).thenAnswer((_) async {});
    when(
      () => mockLocationCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockLocationCubit.state).thenReturn(LocationState.idle());
    when(() => mockLocationCubit.pendingNavigation).thenReturn(false);
    when(() => mockLocationCubit.isRunning).thenReturn(false);
    when(() => mockLocationCubit.elapsed).thenReturn(Duration.zero);

    when(
      () => mockPhoneWearSyncService.sendNavigationPrompt(),
    ).thenAnswer((_) async {});

    when(() => mockActivityCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockActivityCubit.close()).thenAnswer((_) async {});

    when(() => mockProfileCubit.state).thenReturn(Profile(
      nickname: 'test', 
      mail: 'test@mail.com', 
      xp: 150, 
      level: 3,
    ));
    when(() => mockProfileCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockProfileCubit.close()).thenAnswer((_) async {});

    when(
      () => mockFavoriteTrailStore.isFavorite(any()),
    ).thenAnswer((_) async => false);
    when(
      () => mockFavoriteTrailStore.saveTrail(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockFavoriteTrailStore.deleteTrail(any()),
    ).thenAnswer((_) async {});
  });

  tearDownAll(() async {
    HttpOverrides.global = null;
    await getIt.reset();
  });

  group('TrailDetailsScreen Widget Tests', () {
    testWidgets(
      'Show title in app bar and initial circular progress indicator',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: TrailDetailsScreen(trail: trailMap)),
        );

        expect(find.text('Sentiero Test'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('Show error message in case of network error', (
      WidgetTester tester,
    ) async {
      FakeHttpOverrides.shouldFailConnections = true;

      await tester.pumpWidget(
        MaterialApp(home: TrailDetailsScreen(trail: trailMap)),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(
        find.text('Network error. Check your connection and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('Show placeholder when fetching trail details fails', (
      WidgetTester tester,
    ) async {
      FakeHttpOverrides.emptyOverpassRelation = true;

      await tester.pumpWidget(
        MaterialApp(home: TrailDetailsScreen(trail: trailMap)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Informations not available.'), findsOneWidget);
    });

    testWidgets('Show trail details', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TrailDetailsScreen(trail: trailMap)),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Sentiero Test'), findsOneWidget);
      expect(find.text('10.0 km'), findsOneWidget);

      final elevationFinder = find.text(
        'Elevation Profile',
        skipOffstage: false,
      );
      await tester.ensureVisible(elevationFinder);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Elevation Profile'), findsOneWidget);

      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('Show horizontal weather cards correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: TrailDetailsScreen(trail: trailMap)),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Weather Forecast'), findsOneWidget);

      final horizontalListFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal,
      );
      expect(horizontalListFinder, findsOneWidget);

      expect(find.text('Clear sky'), findsOneWidget);
      expect(find.text('Rain'), findsOneWidget);
      expect(find.text('Overcast'), findsOneWidget);

      expect(find.text('25° / 15°'), findsOneWidget);
      expect(find.text('18° / 12°'), findsOneWidget);
      expect(find.text('21° / 14°'), findsOneWidget);
    });

    testWidgets('Show message when weather data is not available', (
      WidgetTester tester,
    ) async {
      FakeHttpOverrides.emptyWeatherForecast = true;

      await tester.pumpWidget(
        MaterialApp(home: TrailDetailsScreen(trail: trailMap)),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Weather data not available.'), findsOneWidget);
    });

    testWidgets('Show message when elevation profile is not available', (
      WidgetTester tester,
    ) async {
      FakeHttpOverrides.emptyElevationData = true;

      await tester.pumpWidget(
        MaterialApp(home: TrailDetailsScreen(trail: trailMap)),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final elevationFinder = find.text(
        'Elevation profile not available.',
        skipOffstage: false,
      );
      await tester.ensureVisible(elevationFinder);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Elevation profile not available.'), findsOneWidget);
    });

    testWidgets('Tap on a web link shows error SnackBar if launch fails', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: TrailDetailsScreen(trail: trailMap)),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final linkFinder = find.textContaining('http');

      if (linkFinder.evaluate().isNotEmpty) {
        await tester.ensureVisible(linkFinder.first);
        await tester.tap(linkFinder.first);

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Could not open the link.'), findsOneWidget);
      }
    });

    testWidgets('Tap on "Plan" navigates to AddActivityPage', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: TrailDetailsScreen(trail: trailMap)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final planButton = find.text('Plan');
      await tester.ensureVisible(planButton);
      await tester.tap(planButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(TrailDetailsScreen), findsNothing);
    });
    testWidgets('Tap on "Start" navigates to NavigatorScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ActivityCubit>(create: (_) => mockActivityCubit),
            BlocProvider<ProfileCubit>(create: (_) => mockProfileCubit),
          ],
          child: MaterialApp(
            home: TrailDetailsScreen(
              trail: trailMap,
              favoriteTrailStore: mockFavoriteTrailStore,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final planButton = find.text('Start');
      await tester.ensureVisible(planButton);
      final startButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Start'),
      );
      expect(startButton.onPressed, isNotNull);
      await tester.tap(planButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TrailDetailsScreen), findsNothing);
    });
  });

  group('Favorites test', () {
    testWidgets('Trail details screen shows star', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrailDetailsScreen(
            trail: trailMap,
            favoriteTrailStore: mockFavoriteTrailStore,
          ),
        ),
      );
      await tester.pump();

      final icon = find.byIcon(Icons.star_border);
      expect(icon, findsOneWidget);
    });

    testWidgets('star is full if trail is favorite', (tester) async {
      when(
        () => mockFavoriteTrailStore.isFavorite(any()),
      ).thenAnswer((_) async => true);
      await tester.pumpWidget(
        MaterialApp(
          home: TrailDetailsScreen(
            trail: trailMap,
            favoriteTrailStore: mockFavoriteTrailStore,
          ),
        ),
      );
      await tester.pump();

      final icon = find.byIcon(Icons.star);
      expect(icon, findsOneWidget);
    });

    testWidgets('adds trail to favorites when not favorite', (tester) async {
      when(
        () => mockFavoriteTrailStore.isFavorite(any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(
        MaterialApp(
          home: TrailDetailsScreen(
            trail: trailMap,
            favoriteTrailStore: mockFavoriteTrailStore,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.star_border));
      await tester.pump();

      verify(() => mockFavoriteTrailStore.saveTrail(any())).called(1);
    });

    testWidgets('removes trail from favorites when already favorite', (
      tester,
    ) async {
      when(
        () => mockFavoriteTrailStore.isFavorite(trailMap['id'].toString()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          home: TrailDetailsScreen(
            trail: trailMap,
            favoriteTrailStore: mockFavoriteTrailStore,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.star));
      await tester.pump();

      verify(
        () => mockFavoriteTrailStore.deleteTrail(trailMap['id'].toString()),
      ).called(1);
    });
  });
}

extension WidgetTesterExtension on WidgetTester {
  Future<void> pumpUntilVisible(
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (this.any(finder) == false) {
      if (DateTime.now().isAfter(endTime)) {
        throw Exception('Timed out waiting for $finder');
      }
      await pump(const Duration(milliseconds: 100));
    }
  }
}
