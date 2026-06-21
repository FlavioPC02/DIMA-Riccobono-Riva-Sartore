import 'dart:math';

import 'package:application/screens/add_activity_page.dart';
import 'package:application/screens/navigator.dart';
import 'package:application/services/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  //TODO: da finire quando ci avrò capito qualcosa
  testWidgets('Plan activity', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));
    
    await login(tester);
    await goToPlanActivity(tester);

    final nameField = find.byKey(Key('name_field'));
    expect(nameField, findsOneWidget);

    final dateField = find.byKey(Key('date_field'));
    expect(dateField, findsOneWidget);

    final state = tester.state<AddActivityPageState>(find.byType(AddActivityPage));
    state.setState(() {
      state.selectedDate = DateTime(2026, 10, 8);
    });

    final saveButton = find.byKey(Key('save_button'));
    expect(saveButton, findsOneWidget);

    await tester.enterText(nameField, 'Test activity');
    
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    await goToPlannedDiaryPage(tester);

    expect(find.text('Test activity'), findsAtLeast(1));
    expect(find.text('08/10/2026'), findsAtLeast(1));
  });
}