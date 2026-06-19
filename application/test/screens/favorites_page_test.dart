import 'dart:async';

import 'package:application/core/models/favorite_trail.dart';
import 'package:application/screens/favorites_page.dart';
import 'package:application/screens/trail_details_screen.dart';
import 'package:application/services/favorite_trail_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../utils/test_config.dart';

class MockFavoriteTrailStore extends Mock implements FavoriteTrailStore {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
    setupTest();
  });

  group('FavoritesPage', () {
    late MockFavoriteTrailStore mockStore;
    late StreamController<List<FavoriteTrail>> streamController;
    late MockNavigatorObserver mockNavigatorObserver;

    setUp(() {
      mockStore = MockFavoriteTrailStore();
      streamController = StreamController<List<FavoriteTrail>>();
      mockNavigatorObserver = MockNavigatorObserver();
      
      when(() => mockStore.streamFavoriteTrails()).thenAnswer((_) => streamController.stream);
    });

    tearDown(() {
      streamController.close();
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        navigatorObservers: [mockNavigatorObserver],
        home: Scaffold(
          body: const FavoritesPage(),
        ),
      );
    }

    testWidgets('shows loading indicator while waiting for stream', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
    });

    testWidgets('shows empty state when stream emits empty list', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      streamController.add([]);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.star), findsNWidgets(2));
      expect(find.textContaining('No favorite trails yet'), findsOneWidget);
    });

    testWidgets('shows list of favorite trails when stream emits data', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final trails = [
        FavoriteTrail(
          id: '1', 
          name: 'Trail Alpha', 
          trailPath: const [],
          distance: '10', 
          duration: '120', 
          difficulty: 1, 
          ascent: '100', 
          isFerrata: false, 
        ),
        FavoriteTrail(
          id: '2', 
          name: 'Trail Beta', 
          trailPath: const [],
          distance: '15', 
          duration: '180', 
          difficulty: 3, 
          ascent: '500', 
          isFerrata: true, 
        ),
      ];

      streamController.add(trails);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Trail Alpha'), findsOneWidget);
      expect(find.text('Trail Beta'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(2));
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    });

    testWidgets('navigates to TrailDetailsScreen when a trail is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final trails = [
        FavoriteTrail(
          id: '1', 
          name: 'Trail Alpha', 
          trailPath: const [],
          distance: '10', 
          duration: '120', 
          difficulty: 1, 
          ascent: '100', 
          isFerrata: false, 
        ),
      ];

      streamController.add(trails);
      await tester.pumpAndSettle();

      expect(find.text('Trail Alpha'), findsOneWidget);

      await tester.tap(find.text('Trail Alpha'));
      await tester.pumpAndSettle();

      verify(() => mockNavigatorObserver.didPush(any(), any())).called(greaterThan(0));
      expect(find.byType(TrailDetailsScreen), findsOneWidget);
    });
  });
}