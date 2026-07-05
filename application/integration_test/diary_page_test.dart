import 'package:application/screens/activity_detail_page.dart';
import 'package:application/screens/navigator.dart';
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

  patrolTest('Go to planned activities and start navigation', ($) async {
    await $.pumpWidgetAndSettle(const app.RootApp());
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await login($);

    final seededId = await seedPlannedActivity();

    await goToDiaryPage($);

    final plannedTab = $('Planned');
    expect(plannedTab, findsOneWidget);

    await $.tap(plannedTab);
    await $.pumpAndSettle();

    final plannedTrails = $(#activity_card);
    expect(plannedTrails, findsAtLeast(1));

    await $.tap(plannedTrails.first);
    await $.pump(const Duration(seconds: 2));

    expect($(ActivityDetailPage), findsOneWidget);

    final startButton = $(#start_button);
    expect(startButton, findsOneWidget);

    await $.scrollUntilVisible(finder: startButton);
    await $.tap(startButton);
    await $.pump(const Duration(seconds: 10));

    expect($(NavigatorScreen), findsOneWidget);

    await deletePlannedActivity(seededId);
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
