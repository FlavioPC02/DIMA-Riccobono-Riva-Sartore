import 'dart:io';
import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/screens/add_activity_page.dart';
import 'package:application/screens/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/screens/trail_details_screen.dart';
import '../utils/trails_details_screen_test_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationCubit extends Mock implements LocationCubit {}

void main() {
  final trailMap = {'id': 12345, 'name': 'Sentiero Test', 'subTrails': []};

  final getIt = GetIt.instance;

  setUpAll(() {
    const envString = '''MAPBOX_ACCESS_TOKEN=test_token_123''';
    dotenv.loadFromString(envString: envString);
    
    HttpOverrides.global = FakeHttpOverrides();
    if (!getIt.isRegistered<LocationCubit>()) {
      getIt.registerSingleton<LocationCubit>(MockLocationCubit());
    }
  });

  setUp(() {
    FakeHttpOverrides.shouldFailConnections = false;
    FakeHttpOverrides.emptyOverpassRelation = false;
    FakeHttpOverrides.emptyWeatherForecast = false;
    FakeHttpOverrides.emptyElevationData = false;
    FakeHttpOverrides.customTags = null;
    FakeHttpOverrides.customWeatherCodes = null;

    final mockLocationCubit = getIt<LocationCubit>();

    when(() => mockLocationCubit.startTracking()).thenAnswer((_) async {});
    when(() => mockLocationCubit.stopAndSave()).thenAnswer((_) async {});
    when(() => mockLocationCubit.close()).thenAnswer((_) async {});
    when(() => mockLocationCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockLocationCubit.state).thenReturn(LocationState.idle());
  });

  tearDownAll(() async {
    HttpOverrides.global = null;
    await getIt.reset();
  });

  group('TrailDetailsScreen Widget Tests', () {
    
    testWidgets('Show title in app bar and initial circular progress indicator', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
      
      expect(find.text('Sentiero Test'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Show error message in case of network error', (WidgetTester tester) async {
      FakeHttpOverrides.shouldFailConnections = true;

      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
      
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(); 

      expect(find.text('Network error. Check your connection and try again.'), findsOneWidget);
    });

    testWidgets('Show placeholder when fetching trail details fails', (WidgetTester tester) async {
      FakeHttpOverrides.emptyOverpassRelation = true;

      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
      
      await tester.pumpAndSettle();

      expect(find.text('Informations not available.'), findsOneWidget);
    });

    testWidgets('Show trail details', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
      
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Sentiero Test'), findsOneWidget);
      expect(find.text('10.0 km'), findsOneWidget);

      final elevationFinder = find.text('Elevation Profile', skipOffstage: false);
      await tester.ensureVisible(elevationFinder);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Elevation Profile'), findsOneWidget);
      
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('Show horizontal weather cards correctly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
      
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Weather Forecast'), findsOneWidget);

      final horizontalListFinder = find.byWidgetPredicate(
        (widget) => widget is ListView && widget.scrollDirection == Axis.horizontal
      );
      expect(horizontalListFinder, findsOneWidget);

      expect(find.text('Clear sky'), findsOneWidget); 
      expect(find.text('Rain'), findsOneWidget); 
      expect(find.text('Overcast'), findsOneWidget);

      expect(find.text('25° / 15°'), findsOneWidget); 
      expect(find.text('18° / 12°'), findsOneWidget);
      expect(find.text('21° / 14°'), findsOneWidget); 
    });

    testWidgets('Show message when weather data is not available', (WidgetTester tester) async {
      FakeHttpOverrides.emptyWeatherForecast = true;

      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
      
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Weather data not available.'), findsOneWidget);
    });

    testWidgets('Show message when elevation profile is not available', (WidgetTester tester) async {
      FakeHttpOverrides.emptyElevationData = true;

      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
      
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final elevationFinder = find.text('Elevation profile not available.', skipOffstage: false);
      await tester.ensureVisible(elevationFinder);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Elevation profile not available.'), findsOneWidget);
    });

    testWidgets('Tap on "Plan" navigates to AddActivityPage', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
      
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final planButton = find.widgetWithText(ElevatedButton, 'Plan');
      await tester.ensureVisible(planButton);
      await tester.tap(planButton);
      
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); 

      expect(find.byType(AddActivityPage), findsOneWidget);
    });

    testWidgets('Tap on "Start" navigates to NavigatorScreen', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
      
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final planButton = find.widgetWithText(ElevatedButton, 'Start');
      await tester.ensureVisible(planButton);
      await tester.tap(planButton);
      
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); 

      expect(find.byType(NavigatorScreen), findsOneWidget);
    });

    testWidgets('Tap on a web link shows error SnackBar if launch fails', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
      
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
  });
}

extension WidgetTesterExtension on WidgetTester {
  Future<void> pumpUntilVisible(Finder finder, {Duration timeout = const Duration(seconds: 5)}) async {
    final endTime = DateTime.now().add(timeout);
    while (this.any(finder) == false) {
      if (DateTime.now().isAfter(endTime)) throw Exception('Timed out waiting for $finder');
      await pump(const Duration(milliseconds: 100));
    }
  }
}