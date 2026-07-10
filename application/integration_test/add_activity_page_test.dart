import 'package:application/screens/add_activity_page.dart';
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

  patrolTest('Plan activity', ($) async {
    await $.pumpWidgetAndSettle(const app.RootApp());
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await login($);
    await goToPlanActivity($);

    if (isTrailDetailsUnavailable($)) {
      expect($(AddActivityPage), findsNothing);
      return;
    }

    final nameField = $(#name_field);
    expect(nameField, findsOneWidget);

    final dateField = $(#date_field);
    expect(dateField, findsOneWidget);

    final state = $.tester.state<AddActivityPageState>($(AddActivityPage));
    state.selectDate(DateTime(2026, 10, 8));

    final saveButton = $(#save_button);
    expect(saveButton, findsOneWidget);

    await $.enterText(nameField, 'Test activity');

    await $.scrollUntilVisible(finder: saveButton);
    await $.tap(saveButton);
    await $.pump();

    expect($('Test activity'), findsAtLeast(1));
    expect($('08/10/2026'), findsAtLeast(1));
  });
}
