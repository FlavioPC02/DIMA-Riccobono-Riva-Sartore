import 'package:application/services/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
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

  testWidgets('Open activity and add note', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await login(tester);
    final seededId = await seedPlannedActivity();
    await goToActivityDetailPage(tester);

    final noteTab = find.text('Notes');
    expect(noteTab, findsOneWidget);
    await tester.tap(noteTab);
    await tester.pump(const Duration(seconds: 2));

    final addNoteButton = find.byKey(Key('add_note'));
    expect(addNoteButton, findsOneWidget);

    await tester.ensureVisible(addNoteButton);
    await tester.tap(addNoteButton);
    await tester.pump(const Duration(seconds: 2));

    final noteTextField = find.byKey(Key('note_text_field'));
    expect(noteTextField, findsOneWidget);

    final saveNoteButton = find.byKey(Key('save_note_button'));
    expect(saveNoteButton, findsOneWidget);

    await tester.enterText(noteTextField, 'Trial notes');
    await tester.tap(saveNoteButton);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Trial notes'), findsOneWidget);

    await deletePlannedActivity(seededId);
  });
}
