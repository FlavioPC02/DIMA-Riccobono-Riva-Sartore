import 'package:application/screens/activity_detail_page.dart';
import 'package:application/screens/navigator.dart';
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

  testWidgets('Go to planned activities and start navigation', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await login(tester);
    await goToDiaryPage(tester);

    final plannedTab = find.text('Planned');
    expect(plannedTab, findsOneWidget);

    await tester.tap(plannedTab);
    await tester.pumpAndSettle();

    final plannedTrails = find.byKey(Key('activity_card'));
    expect(plannedTrails, findsAtLeast(1));

    await tester.tap(plannedTrails.first);
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(ActivityDetailPage), findsOneWidget);

    final startButton = find.byKey(Key('start_button'));
    expect(startButton, findsOneWidget);

    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.byType(NavigatorScreen), findsOneWidget);
    //TODO: non salvo online il percorso, quindi se lo storage locale viene distrutto per un motivo X non so come recuperare i dati

    //TODO: se non ci sono trails va aggiunto a manina -> da capire come fare quando mi rispondono
  });

  testWidgets('Go to completed activities and open one', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await login(tester);
    await goToDiaryPage(tester);

    final completedTab = find.text('Completed');
    expect(completedTab, findsOneWidget);

    await tester.tap(completedTab);
    await tester.pumpAndSettle();

    final completedTrails = find.byKey(Key('activity_card'));
    expect(completedTrails, findsAtLeast(1));

    await tester.tap(completedTrails.first);
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(ActivityDetailPage), findsOneWidget);
  });
}
