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

  patrolTest('Open activity and add note', ($) async {
    await $.pumpWidgetAndSettle(
      const app.RootApp(),
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await login($);
    final seededId = await seedPlannedActivity();
    await goToActivityDetailPage($);

    final noteTab = $('Notes');
    expect(noteTab, findsOneWidget);
    await $.tap(noteTab);
    await $.pump(const Duration(seconds: 2));

    final addNoteButton = $(#add_note);
    expect(addNoteButton, findsOneWidget);

    await $.scrollUntilVisible(finder: addNoteButton);
    await $.tap(addNoteButton);
    await $.pump(const Duration(seconds: 2));

    final noteTextField = $(#note_text_field);
    expect(noteTextField, findsOneWidget);

    final saveNoteButton = $(#save_note_button);
    expect(saveNoteButton, findsOneWidget);

    await $.enterText(noteTextField, 'Trial notes');
    await $.tap(saveNoteButton);
    await $.pump(const Duration(seconds: 2));

    expect($('Trial notes'), findsAtLeast(1));

    await deletePlannedActivity(seededId);
  });
}
