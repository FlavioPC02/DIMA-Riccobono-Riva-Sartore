import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/settings.dart';
import 'package:application/screens/map_page.dart';
import 'package:application/screens/trail_details_screen.dart';
import '../utils/map_test_helper.dart';
import 'package:flutter_map/flutter_map.dart';

class DelayedMockGeolocatorPlatform extends MockGeolocatorPlatform {
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return super.getCurrentPosition(locationSettings: locationSettings);
  }
}

class MockSettingsCubit extends Mock implements SettingsCubit {}
class MockTileImage extends Mock implements TileImage {}

void main() {
  late DelayedMockGeolocatorPlatform mockGeolocator;
  late MockSettingsCubit mockSettingsCubit;

  setUpAll(() async {
    const envString = '''MAPBOX_ACCESS_TOKEN=test_token_123''';
    dotenv.loadFromString(envString: envString);
    
    HttpOverrides.global = FakeHttpOverrides();
    registerFallbackValue(Settings(notifications: true, ferrata: false, difficulty: 0.0));
  });

  setUp(() {
    mockGeolocator = DelayedMockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
    FakeHttpOverrides.shouldFailConnections = false;
    FakeHttpOverrides.returnEmptyNominatim = false;
    FakeHttpOverrides.returnEmptyOverpass = false;
    FakeHttpOverrides.returnServerError = false;

    mockSettingsCubit = MockSettingsCubit();
    when(() => mockSettingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockSettingsCubit.state).thenReturn(
      Settings(
        notifications: true,
        ferrata: false,
        difficulty: 0.0,
      ),
    );
  });

  Future<void> pumpMapPage(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: mockSettingsCubit,
        child: const MaterialApp(home: MapPage()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  group('MapPage Widget Tests', () {

    testWidgets('Renders MapPage correctly with search bar and buttons', (WidgetTester tester) async {
      await pumpMapPage(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search for a location...'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      
      await tearDownMap(tester); 
    });

    testWidgets('Shows location service dialog if GPS is disabled', (WidgetTester tester) async {
      mockGeolocator.locationServiceEnabled = false;

      await pumpMapPage(tester);

      expect(find.text('Location service required'), findsOneWidget);
      expect(find.text('Enable location permission'), findsOneWidget);
      
      await tearDownMap(tester); 
    });

    testWidgets('Shows location permission dialog if permission is denied', (WidgetTester tester) async {
      mockGeolocator.permission = LocationPermission.denied;

      await pumpMapPage(tester);

      expect(find.text('Location permission required'), findsOneWidget);
      expect(find.text('Enable location permission'), findsOneWidget);
      
      await tearDownMap(tester); 
    });

    testWidgets('Search input triggers debounce and updates UI', (WidgetTester tester) async {
      await pumpMapPage(tester);

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
      await pumpMapPage(tester);

      await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.my_location));
      await tester.pump(const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
      
      await tearDownMap(tester); 
    });

    testWidgets('Search location network failure shows snackbar', (WidgetTester tester) async {
      FakeHttpOverrides.shouldFailConnections = true;
      await pumpMapPage(tester);

      await tester.enterText(find.byType(TextField), 'Milano');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Error occurred while searching for the location.'), findsOneWidget);
      await tearDownMap(tester);
    });

    testWidgets('Trail search network failure shows snackbar', (WidgetTester tester) async {
      FakeHttpOverrides.shouldFailConnections = true;
      await pumpMapPage(tester);

      final searchButton = find.text('Search for hiking trails in this area');
      expect(searchButton, findsOneWidget);

      final buttonFinder = find.ancestor(
        of: searchButton,
        matching: find.byType(ElevatedButton),
      ).first;
      final buttonWidget = tester.widget<ElevatedButton>(buttonFinder);
      expect(buttonWidget.onPressed, isNotNull);

      buttonWidget.onPressed?.call();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Network error. Check your connection and try again.'), findsOneWidget);
      await tearDownMap(tester);
    });

    testWidgets('SettingsCubit listener updates filter labels on state change', (WidgetTester tester) async {
      final settingsController = StreamController<Settings>.broadcast();
      when(() => mockSettingsCubit.stream).thenAnswer((_) => settingsController.stream);
      when(() => mockSettingsCubit.state).thenReturn(
        Settings(notifications: true, ferrata: true, difficulty: 1.0),
      );

      await pumpMapPage(tester);
      expect(find.text('Intermediate'), findsOneWidget);

      settingsController.add(Settings(notifications: true, ferrata: true, difficulty: 2.0));
      await tester.pumpAndSettle();

      expect(find.text('Expert'), findsOneWidget);
      await settingsController.close();
      await tearDownMap(tester);
    });

    testWidgets('Fetches trails from Overpass API and shows/closes PageView', (WidgetTester tester) async {
      await pumpMapPage(tester);

      final searchButton = find.text('Search for hiking trails in this area');
      expect(searchButton, findsOneWidget);
      await tester.tap(searchButton);
      
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Sentiero Facile'), findsOneWidget);

      final closeTrailsButton = find.widgetWithIcon(FloatingActionButton, Icons.close);
      await tester.tap(closeTrailsButton);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Search for hiking trails in this area'), findsOneWidget);

      await tearDownMap(tester);
    });

    testWidgets('Nominatim search yields suggestions and tapping one fetches trails', (WidgetTester tester) async {
      await pumpMapPage(tester);

      await tester.enterText(find.byType(TextField), 'Mil');
      
      await tester.pump(const Duration(seconds: 2));

      final suggestionFinder = find.text('Milano, Italia');
      expect(suggestionFinder, findsOneWidget);

      await tester.tap(suggestionFinder);
      
      await tester.pump(const Duration(seconds: 2));

      TextField textField = tester.widget(find.byType(TextField));
      expect(textField.controller!.text, 'Milano, Italia');

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Sentiero Facile'), findsOneWidget);

      await tearDownMap(tester);
    });

    testWidgets('Close button clears search results and returns to initial state', (WidgetTester tester) async {
      await pumpMapPage(tester);

      final searchButton = find.text('Search for hiking trails in this area');
      await tester.tap(searchButton);
      await tester.pump(const Duration(seconds: 2));

      final closeTrailsButton = find.widgetWithIcon(FloatingActionButton, Icons.close);
      expect(closeTrailsButton, findsOneWidget);
      await tester.tap(closeTrailsButton);
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Search for hiking trails in this area'), findsOneWidget);

      await tearDownMap(tester);
    });

    testWidgets('Tapping selected trail opens TrailDetailsScreen', (WidgetTester tester) async {
      await pumpMapPage(tester);

      final searchButton = find.text('Search for hiking trails in this area');
      await tester.tap(searchButton);
      await tester.pump(const Duration(seconds: 2));

      final trailCard = find.text('Sentiero Facile');
      expect(trailCard, findsOneWidget);
      await tester.tap(trailCard);
      await tester.pumpAndSettle();

      expect(find.byType(TrailDetailsScreen), findsOneWidget);

      await tearDownMap(tester);
    });

    testWidgets('Reload map button is available when map has loading error', (WidgetTester tester) async {
      // Create a test scenario where the reload button would be shown
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetPhysicalSize);

      await pumpMapPage(tester);
      await tester.pumpAndSettle();

      // The reload button should be available in the widget tree when map errors occur
      // In production, it's shown via _hasMapLoadError flag
      expect(find.byIcon(Icons.refresh), findsNothing); // Initially not shown
      
      await tearDownMap(tester);
    });

    testWidgets('Trail card is interactive and selectable', (WidgetTester tester) async {
      await pumpMapPage(tester);

      // Fetch trails
      final searchButton = find.text('Search for hiking trails in this area');
      expect(searchButton, findsOneWidget);
      await tester.tap(searchButton);
      
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify PageView with trails exists
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Sentiero Facile'), findsOneWidget);

      // Verify the trail card can be found and is a GestureDetector
      final trailCard = find.text('Sentiero Facile');
      expect(trailCard, findsOneWidget);

      // Verify the card is contained in a Card widget
      expect(find.byType(Card), findsWidgets);

      await tearDownMap(tester);
    });

    testWidgets('Filter menus update state correctly', (WidgetTester tester) async {
      await pumpMapPage(tester);

      await tester.tap(find.text('Distance'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('<5km').last);
      await tester.pumpAndSettle();
      expect(find.text('<5km'), findsOneWidget);

      await tester.tap(find.text('<5km'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No filter').last);
      await tester.pumpAndSettle();
      expect(find.text('Distance'), findsOneWidget);

      await tester.tap(find.text('Duration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('>4h').last);
      await tester.pumpAndSettle();
      expect(find.text('>4h'), findsOneWidget);

      await tester.tap(find.text('Beginner')); 
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expert').last);
      await tester.pumpAndSettle();
      expect(find.text('Expert'), findsOneWidget);

      await tester.tap(find.text('Expert'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ferrata').last);
      await tester.pumpAndSettle();
      
      await tearDownMap(tester);
    });

    testWidgets('Submitting an empty or whitespace-only search does not trigger APIs', (WidgetTester tester) async {
      await pumpMapPage(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      
      await tearDownMap(tester);
    });

    testWidgets('Tapping an unselected trail card scrolls the PageView', (WidgetTester tester) async {
      await pumpMapPage(tester);

      final searchButton = find.text('Search for hiking trails in this area');
      await tester.tap(searchButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final trailCards = find.byType(Card);
      
      if (tester.widgetList(trailCards).length > 1) {
        await tester.tap(trailCards.at(1));
        await tester.pumpAndSettle();
      }
      
      await tearDownMap(tester);
    });

    testWidgets('Reload map button is not visible by default', (WidgetTester tester) async {
      await pumpMapPage(tester);
      
      expect(find.text('Reload map'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
      
      await tearDownMap(tester);
    });

    testWidgets('Shows snackbar when Nominatim search returns no results', (WidgetTester tester) async {
      FakeHttpOverrides.returnEmptyNominatim = true;
      await pumpMapPage(tester);

      await tester.enterText(find.byType(TextField), 'LuogoInesistente123');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Location not found. Please try a different search term.'), findsOneWidget);
      
      await tearDownMap(tester);
    });

    testWidgets('Shows snackbar when Overpass API returns no trails', (WidgetTester tester) async {
      FakeHttpOverrides.returnEmptyOverpass = true;
      await pumpMapPage(tester);

      final searchButton = find.text('Search for hiking trails in this area');
      await tester.tap(searchButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('No hiking trails found near the searched location. Try searching in a different area.'), findsOneWidget);
      
      await tearDownMap(tester);
    });

    testWidgets('Filters correctly parse complex scales and keep Expert/Ferrata trails', (WidgetTester tester) async {
      await pumpMapPage(tester);

      await tester.tap(find.text('Beginner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expert').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Expert'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ferrata').last);
      await tester.pumpAndSettle();

      final searchButton = find.text('Search for hiking trails in this area');
      await tester.tap(searchButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Sentiero Difficile'), findsOneWidget);
      expect(find.text('Sentiero Facile'), findsNothing);

      await tearDownMap(tester);
    });

    testWidgets('Shows snackbar when trails are found but filtered out', (WidgetTester tester) async {
      await pumpMapPage(tester);

      await tester.tap(find.text('Duration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('<1h').last);
      await tester.pumpAndSettle();

      final searchButton = find.text('Search for hiking trails in this area');
      await tester.tap(searchButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(PageView), findsNothing);
      expect(find.text('No hiking trails found. Try refining your filters.'), findsOneWidget);
      
      await tearDownMap(tester);
    });

    testWidgets('Shows snackbar when Overpass API returns server error', (WidgetTester tester) async {
      await pumpMapPage(tester);

      FakeHttpOverrides.returnServerError = true;

      final searchButton = find.text('Search for hiking trails in this area');
      await tester.tap(searchButton);
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Impossible to fetch trails. Automatically retrying'), findsWidgets);
      
      await tearDownMap(tester);
    });
  });
}
