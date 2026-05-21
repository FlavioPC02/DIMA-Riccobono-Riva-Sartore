import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'package:application/screens/map_page.dart';

import '../utils/map_test_helper.dart';

void main() {
  late MockGeolocatorPlatform mockGeolocator;

  setUpAll(() async {
    dotenv.testLoad(fileInput: '''MAPBOX_ACCESS_TOKEN=test_token_123''');
    
    HttpOverrides.global = FakeHttpOverrides();
  });

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
  });

  group('MapPage Widget Tests', () {

    testWidgets('Renders MapPage correctly with search bar and buttons', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: MapPage()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search for a location...'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      
      await tearDownMap(tester); 
    });

    testWidgets('Shows location service dialog if GPS is disabled', (WidgetTester tester) async {
      mockGeolocator.locationServiceEnabled = false;

      await tester.pumpWidget(const MaterialApp(home: MapPage()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Location service required'), findsOneWidget);
      expect(find.text('Enable location permission'), findsOneWidget);
      
      await tearDownMap(tester); 
    });

    testWidgets('Shows location permission dialog if permission is denied', (WidgetTester tester) async {
      mockGeolocator.permission = LocationPermission.denied;

      await tester.pumpWidget(const MaterialApp(home: MapPage()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Location permission required'), findsOneWidget);
      expect(find.text('Enable location permission'), findsOneWidget);
      
      await tearDownMap(tester); 
    });

    testWidgets('Search input triggers debounce and updates UI', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: MapPage()));
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'Milano');
      await tester.pump(); 
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      
      TextField textField = tester.widget(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
      
      await tearDownMap(tester); 
    });

    testWidgets('Center map on user button works', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: MapPage()));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.my_location));
      await tester.pump(const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
      
      await tearDownMap(tester); 
    });

    testWidgets('Fetches trails from Overpass API and shows/closes PageView', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: MapPage()));
      await tester.pump(const Duration(seconds: 1));

      final searchButton = find.text('Search for hiking trails in this area');
      expect(searchButton, findsOneWidget);
      await tester.tap(searchButton);
      
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Sentiero Test Coverage'), findsOneWidget);

      final closeTrailsButton = find.widgetWithIcon(FloatingActionButton, Icons.close);
      await tester.tap(closeTrailsButton);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Search for hiking trails in this area'), findsOneWidget);

      await tearDownMap(tester);
    });

    testWidgets('Nominatim search yields suggestions and tapping one fetches trails', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: MapPage()));
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'Mil');
      
      await tester.pump(const Duration(seconds: 2));

      final suggestionFinder = find.text('Milano, Italia');
      expect(suggestionFinder, findsOneWidget);

      await tester.tap(suggestionFinder);
      
      await tester.pump(const Duration(seconds: 2));

      TextField textField = tester.widget(find.byType(TextField));
      expect(textField.controller!.text, 'Milano, Italia');

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Sentiero Test Coverage'), findsOneWidget);

      await tearDownMap(tester);
    });
  });
}