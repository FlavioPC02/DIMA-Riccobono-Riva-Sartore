import 'package:application/screens/add_activity_page.dart';
import 'package:application/screens/navigator.dart';
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

  patrolTest('Plan activity', ($) async {
    await $.pumpWidgetAndSettle(const app.RootApp());
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await login($);
    await goToTrailDetailPage($);

    final planButton = await searchWidgetInNTries($, Key('plan_trail'));
    expect(planButton, findsOneWidget);

    await $.tap(planButton);
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    expect($(AddActivityPage), findsOneWidget);
  });

  patrolTest('Start tracking', ($) async {
    await $.pumpWidgetAndSettle(const app.RootApp());
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await login($);
    await goToTrailDetailPage($);

    final navigateButton = await searchWidgetInNTries($, Key('start_tracking_trail'), maxRetries: 10);
    expect(navigateButton, findsOneWidget);

    await $.tap(navigateButton);
    await $.pump(const Duration(seconds: 10));

    expect($(NavigatorScreen), findsOneWidget);
  });
}