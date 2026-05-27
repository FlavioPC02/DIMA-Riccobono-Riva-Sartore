import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/screens/trail_details_screen.dart';
import '../utils/trails_details_screen_test_helper.dart';

void main() {
  final trailMap = {'id': 12345, 'name': 'Sentiero Test'};

  setUpAll(() {
    HttpOverrides.global = FakeHttpOverrides();
  });

  setUp(() {
    FakeHttpOverrides.shouldFailConnections = false;
    FakeHttpOverrides.emptyOverpassRelation = false;
    FakeHttpOverrides.emptyWeatherForecast = false;
    FakeHttpOverrides.emptyElevationData = false;
  });

  tearDownAll(() {
    HttpOverrides.global = null;
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
  });
}

extension WidgetTesterExtension on WidgetTester {
  Future<void> pumpUntilVisible(Finder finder, {Duration timeout = const Duration(seconds: 5)}) async {
    final endTime = DateTime.now().add(timeout);
    while (any(finder) == false) {
      if (DateTime.now().isAfter(endTime)) throw Exception('Timed out waiting for $finder');
      await pump(const Duration(milliseconds: 100));
    }
  }
}