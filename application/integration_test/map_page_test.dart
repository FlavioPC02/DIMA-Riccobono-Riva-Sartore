import 'package:application/screens/trail_details_screen.dart';
import 'package:application/services/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  group('Search', () {
    patrolTest('Search for locations and trails', ($) async {
      await $.pumpWidgetAndSettle(const app.RootApp());
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await login($);

      final searchBar = $(#search_field);
      expect(searchBar, findsOneWidget);

      const location = 'Trento';

      await $.enterText(searchBar, location);
      await $.pump(const Duration(seconds: 2));

      const maxRetries = 3;
      var trail = $(#found_trail);

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        final searchButtonFinder = $(#search_trail_button);

        if (searchButtonFinder.exists) {
          final searchButton = $.tester.widget<ElevatedButton>(
            searchButtonFinder,
          );

          if (searchButton.onPressed != null) {
            await $(location).first.tap();
            await $.tester.testTextInput.receiveAction(TextInputAction.search);
            await $.pump(const Duration(seconds: 20));
          } else {
            // still mid-request; wait for it to finish before checking again
            await $.pump(const Duration(seconds: 2));
            continue;
          }
        }

        trail = $(#found_trail);

        if (trail.exists) break;

        await $.pump(const Duration(seconds: 5));
      }

      expect(trail, findsAtLeast(1));
    });

    patrolTest('Search for trails and open trail detail page', ($) async {
      await $.pumpWidgetAndSettle(const app.RootApp());
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await login($);

      const maxRetries = 3;
      var trail = $(#found_trail);

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        final searchButtonFinder = $(#search_trail_button);

        if (searchButtonFinder.exists) {
          final searchButton = $.tester.widget<ElevatedButton>(
            searchButtonFinder,
          );

          if (searchButton.onPressed != null) {
            await $.tap(searchButtonFinder);
            await $.pump(const Duration(seconds: 15));
          } else {
            // still mid-request; wait for it to finish before checking again
            await $.pump(const Duration(seconds: 2));
            continue;
          }
        }

        trail = $(#found_trail);

        if (trail.exists) break;

        await $.pump(const Duration(seconds: 5));
      }

      expect(trail, findsAtLeast(1));

      await $.tap(trail.first);
      await $.pump(const Duration(seconds: 2));

      expect($(TrailDetailsScreen), findsOneWidget);
    });
  });
}
