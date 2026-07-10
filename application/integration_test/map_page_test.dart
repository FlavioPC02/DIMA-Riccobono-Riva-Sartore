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

bool _isMapSearchMessageVisible(PatrolIntegrationTester $) {
  return $('Network error. Check your connection and try again.').exists ||
      $('Check your connection and try again.').exists ||
      $('Error occurred while searching for hiking trails').exists ||
      $('Error occurred while searching for the location.').exists ||
      $('No hiking trails found. Try refining your filters.').exists ||
      $(
        'No hiking trails found near the searched location. Try searching in a different area.',
      ).exists ||
      $('Server error: Impossible to fetch trails. Try again later').exists;
}

Future<bool> _pumpCheckingMapSearchMessages(
  PatrolIntegrationTester $,
  Duration duration,
) async {
  final endTime = DateTime.now().add(duration);
  var sawMessage = false;

  while (DateTime.now().isBefore(endTime)) {
    await $.pump(const Duration(milliseconds: 250));
    sawMessage |= _isMapSearchMessageVisible($);
    if ($(#found_trail).exists || sawMessage) {
      return sawMessage;
    }
  }

  return sawMessage;
}

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
      var sawSearchMessage = false;

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        final searchButtonFinder = $(#search_trail_button);

        if (searchButtonFinder.exists) {
          final searchButton = $.tester.widget<ElevatedButton>(
            searchButtonFinder,
          );

          if (searchButton.onPressed != null) {
            await $(location).first.tap();
            await $.tester.testTextInput.receiveAction(TextInputAction.search);
            sawSearchMessage |= await _pumpCheckingMapSearchMessages(
              $,
              const Duration(seconds: 20),
            );
          } else {
            // still mid-request; wait for it to finish before checking again
            sawSearchMessage |= await _pumpCheckingMapSearchMessages(
              $,
              const Duration(seconds: 2),
            );
            continue;
          }
        }

        trail = $(#found_trail);

        if (trail.exists) break;

        sawSearchMessage |= await _pumpCheckingMapSearchMessages(
          $,
          const Duration(seconds: 5),
        );
      }

      if (sawSearchMessage) {
        expect(trail, findsNothing);
        return;
      }

      expect(trail, findsAtLeast(1));
    });

    patrolTest('Search for trails and open trail detail page', ($) async {
      await $.pumpWidgetAndSettle(const app.RootApp());
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await login($);

      const maxRetries = 3;
      var trail = $(#found_trail);
      var sawSearchMessage = false;

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        final searchButtonFinder = $(#search_trail_button);

        if (searchButtonFinder.exists) {
          final searchButton = $.tester.widget<ElevatedButton>(
            searchButtonFinder,
          );

          if (searchButton.onPressed != null) {
            await $.tap(searchButtonFinder);
            sawSearchMessage |= await _pumpCheckingMapSearchMessages(
              $,
              const Duration(seconds: 15),
            );
          } else {
            // still mid-request; wait for it to finish before checking again
            sawSearchMessage |= await _pumpCheckingMapSearchMessages(
              $,
              const Duration(seconds: 2),
            );
            continue;
          }
        }

        trail = $(#found_trail);

        if (trail.exists) break;

        sawSearchMessage |= await _pumpCheckingMapSearchMessages(
          $,
          const Duration(seconds: 5),
        );
      }

      if (sawSearchMessage) {
        expect(trail, findsNothing);
        return;
      }

      expect(trail, findsAtLeast(1));

      await $.tap(trail.first);
      await $.pump(const Duration(seconds: 2));

      expect($(TrailDetailsScreen), findsOneWidget);
    });
  });
}
