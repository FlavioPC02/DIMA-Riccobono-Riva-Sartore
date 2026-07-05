import 'package:application/screens/diary_page.dart';
import 'package:application/screens/favorites_page.dart';
import 'package:application/screens/map_page.dart';
import 'package:application/screens/profile_screen.dart';
import 'package:application/services/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:application/main.dart' as app;
import 'package:patrol/patrol.dart';

import 'utils/interactions.dart';

void main() {
  patrolSetUp(() async {
    await appSetup();
  });

  patrolTearDown(() async {
    await FirebaseAuth.instance.signOut();
    await sl.reset();
  });

  tearDownAll(() async {
    await HydratedBloc.storage.clear();
    await Hive.deleteFromDisk();
  });

  group('Bottom bar navigation', () {
    patrolTest('From map page to profile page and back', ($) async {
      await $.pumpWidgetAndSettle(const app.RootApp());
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await login($);

      final profileShortcut = $('Profile');
      expect(profileShortcut, findsOneWidget);

      await $.tap(profileShortcut);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      expect($(ProfilePage), findsOneWidget);

      final mapShorcut = $('Map');
      expect(mapShorcut, findsOneWidget);

      await $.tap(mapShorcut);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      expect($(MapPage), findsOneWidget);
    });

    patrolTest('From map page to diary page and back', ($) async {
      await $.pumpWidgetAndSettle(const app.RootApp());
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await login($);

      final diaryShortcut = $('Diary');
      expect(diaryShortcut, findsOneWidget);

      await $.tap(diaryShortcut);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      expect($(DiaryPage), findsOneWidget);

      final mapShorcut = $('Map');
      expect(mapShorcut, findsOneWidget);

      await $.tap(mapShorcut);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      expect($(MapPage), findsOneWidget);
    });

    patrolTest('From map page to favorites page', ($) async {
      await $.pumpWidgetAndSettle(const app.RootApp());
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await login($);

      final favoritesShortcut = $('Favorites');
      expect(favoritesShortcut, findsOneWidget);

      await $.tap(favoritesShortcut);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      expect($(FavoritesPage), findsOneWidget);

      final mapShorcut = find.text('Map');
      expect(mapShorcut, findsOneWidget);

      await $.tap(mapShorcut);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      expect($(MapPage), findsOneWidget);
    });
  });
}
