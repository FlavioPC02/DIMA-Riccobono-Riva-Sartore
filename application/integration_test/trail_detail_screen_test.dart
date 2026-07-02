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

  testWidgets('Plan activity', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await login(tester);
    await goToTrailDetailPage(tester);

    final planButton = find.byKey(Key('plan_trail'));
    expect(planButton, findsOneWidget);

    await tester.tap(planButton);
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.byType(AddActivityPage), findsOneWidget);
  });

  testWidgets('Start tracking', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await login(tester);
    await goToTrailDetailPage(tester);

    final navigateButton = await searchWidgetInNTries(tester, Key('start_tracking_trail'), maxRetries: 10);
    expect(navigateButton, findsOneWidget);

    await tester.tap(navigateButton);
    await tester.pump(const Duration(seconds: 10));

    expect(find.byType(NavigatorScreen), findsOneWidget);
  });
}