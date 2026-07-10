import 'package:application/screens/activity_detail_page.dart';
import 'package:application/screens/navigator.dart';
import 'package:application/services/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
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

  patrolTest('Go to planned activities and start navigation', ($) async {
    await $.pumpWidgetAndSettle(const app.RootApp());
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await login($);

    final seeded = await seedNamedPlannedActivityInApp($);
    try {
      await goToDiaryPage($);

      final plannedTab = $('Planned');
      expect(plannedTab, findsOneWidget);

      await $.tap(plannedTab);
      await $.pumpAndSettle();

      final seededActivity = $(seeded.name);
      expect(seededActivity, findsAtLeast(1));

      await Scrollable.ensureVisible(
        $.tester.element(find.text(seeded.name).last),
        duration: const Duration(milliseconds: 300),
      );
      await $.pumpAndSettle();
      await $.tester.tap(find.text(seeded.name).last);
      await $.pump(const Duration(seconds: 2));

      expect($(ActivityDetailPage), findsOneWidget);

      final startButton = $(#start_button);
      expect(startButton, findsOneWidget);

      await $.scrollUntilVisible(finder: startButton);
      await $.tap(startButton);
      await $.pump(const Duration(seconds: 10));

      expect($(NavigatorScreen), findsOneWidget);
    } finally {
      await deletePlannedActivity(seeded.id);
    }
  });

  patrolTest('Go to completed activities and open one', ($) async {
    await $.pumpWidgetAndSettle(const app.RootApp());
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await login($);
    await goToDiaryPage($);

    final completedTab = $('Completed');
    expect(completedTab, findsOneWidget);

    await $.tap(completedTab);
    await $.pumpAndSettle();

    final completedTrails = $(#activity_card);
    expect(completedTrails, findsAtLeast(1));

    await $.tap(completedTrails.first);
    await $.pump(const Duration(seconds: 2));

    expect($(ActivityDetailPage), findsOneWidget);
  });
}
