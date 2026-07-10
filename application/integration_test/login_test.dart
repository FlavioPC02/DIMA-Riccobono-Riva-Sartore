import 'package:application/screens/login_screen.dart';
import 'package:application/screens/map_page.dart';
import 'package:application/services/helpers/background_service_helper.dart';
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
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
    await sl.reset();
  });

  tearDownAll(() async {
    await HydratedBloc.storage.clear();
    await Hive.deleteFromDisk();
  });

  patrolTest('log in and navigate to homepage', ($) async {
    await $.pumpWidgetAndSettle(const app.RootApp());

    await $(LoginScreen).waitUntilVisible();

    final emailForm = $(#login_mail);
    expect(emailForm, findsOneWidget);

    final passwordForm = $(#login_password);
    expect(passwordForm, findsOneWidget);

    await $.enterText(emailForm, 'integration@test.it');
    await $.enterText(passwordForm, 'password');

    final signInButton = $(#login_button);
    expect(signInButton, findsOneWidget);

    await $.tap(signInButton);
    await settleAfterLogin($);

    expect($(MapPage), findsOneWidget);
  });

  patrolTest('Logout', ($) async {
    await $.pumpWidgetAndSettle(const app.RootApp());
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await login($);
    await goToProfilePage($);

    final logoutButton = $(#logout_button);
    expect(logoutButton, findsOneWidget);

    await $.scrollUntilVisible(finder: logoutButton);
    await $.tap(logoutButton);

    await $.pumpAndSettle(timeout: const Duration(seconds: 20));

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
