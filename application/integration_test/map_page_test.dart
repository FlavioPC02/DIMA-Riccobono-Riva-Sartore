import 'package:application/screens/trail_details_screen.dart';
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

  group('Search', () {
    testWidgets('Search for locations and trails', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await login(tester);

      final searchBar = find.byKey(Key('search_field'));
      expect(searchBar, findsOneWidget);

      await tester.enterText(searchBar, 'Trento');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final trail = find.byKey(Key('found_trail'));
      expect(trail, findsAtLeast(1));
    });

    testWidgets('Search for trails and open trail detail page', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await login(tester);

      final searchButton = find.byKey(Key('search_trail_button'));
      expect(searchButton, findsOneWidget);

      await tester.tap(searchButton);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final trail = find.byKey(Key('found_trail'));
      expect(trail, findsAtLeast(1));

      await tester.tap(trail.first);
      await tester.pump(const Duration(seconds: 10));
      
      expect(find.byType(TrailDetailsScreen), findsOneWidget);
    });
  });
}