import 'package:application/screens/map_page.dart';
import 'package:application/screens/navigator.dart';
import 'package:application/services/service_locator.dart';
import 'package:application/widgets/stats_recording_card.dart';
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

  testWidgets('Stop tracking takes back to map page', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await login(tester);
    await goToNavigatorScreen(tester);

    expect(find.byType(NavigatorScreen), findsOneWidget);
    
    final statsRecordingCard = find.byType(StatsRecordingCard);
    expect(statsRecordingCard, findsOneWidget);

    final dragHandle = find.byKey(Key('sheet_drag_handle'));
    expect(dragHandle, findsOneWidget);

    await tester.timedDrag(
      dragHandle,
      const Offset(0, -400),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();

    final stopButton = find.byKey(Key('stop_button'));
    expect(stopButton, findsOneWidget);

    await tester.ensureVisible(stopButton);
    await tester.tap(stopButton);
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.byType(MapPage), findsOneWidget);
  });
}