import 'package:application/screens/diary_page.dart';
import 'package:application/screens/favorites_page.dart';
import 'package:application/screens/map_page.dart';
import 'package:application/screens/profile_screen.dart';
import 'package:application/services/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:application/main.dart' as app;

import 'utils/interactions.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
    await sl.reset();
  });

  tearDownAll(() async {
    await HydratedBloc.storage.clear();
    await Hive.deleteFromDisk();
  });

  group('Bottom bar navigation', () {
    testWidgets('From map page to profile page and back', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await login(tester);

      final profileShortcut = find.text('Profile');
      expect(profileShortcut, findsOneWidget);

      await tester.tap(profileShortcut);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(ProfilePage), findsOneWidget);

      final mapShorcut = find.text('Map');
      expect(mapShorcut, findsOneWidget);

      await tester.tap(mapShorcut);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(MapPage), findsOneWidget);
    });

    testWidgets('From map page to diary page and back', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await login(tester);

      final diaryShortcut = find.text('Diary');
      expect(diaryShortcut, findsOneWidget);

      await tester.tap(diaryShortcut);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(DiaryPage), findsOneWidget);

      final mapShorcut = find.text('Map');
      expect(mapShorcut, findsOneWidget);

      await tester.tap(mapShorcut);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(MapPage), findsOneWidget);
    });

    testWidgets('From map page to favorites page', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await login(tester);

      final favoritesShortcut = find.text('Favorites');
      expect(favoritesShortcut, findsOneWidget);

      await tester.tap(favoritesShortcut);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(FavoritesPage), findsOneWidget);

      final mapShorcut = find.text('Map');
      expect(mapShorcut, findsOneWidget);

      await tester.tap(mapShorcut);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(MapPage), findsOneWidget);
    });
  });
}
