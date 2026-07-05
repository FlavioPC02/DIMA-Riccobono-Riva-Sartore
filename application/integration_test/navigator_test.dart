import 'package:application/screens/map_page.dart';
import 'package:application/screens/navigator.dart';
import 'package:application/services/service_locator.dart';
import 'package:application/widgets/stats_recording_card.dart';
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

  patrolTest('Stop tracking takes back to map page', ($) async {
    await $.pumpWidgetAndSettle(const app.RootApp());
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await login($);
    await goToNavigatorScreen($);

    expect(find.byType(NavigatorScreen), findsOneWidget);
    
    final statsRecordingCard = $(StatsRecordingCard);
    expect(statsRecordingCard, findsOneWidget);

    final dragHandle = $(#sheet_drag_handle);
    expect(dragHandle, findsOneWidget);

    await $.tester.timedDrag(
      dragHandle,
      const Offset(0, -400),
      const Duration(milliseconds: 800),
    );
    await $.pumpAndSettle();

    final stopButton = $(#stop_button);
    expect(stopButton, findsOneWidget);

    await $.scrollUntilVisible(finder: stopButton);
    await $.tap(stopButton);
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    expect($(MapPage), findsOneWidget);
  });
}