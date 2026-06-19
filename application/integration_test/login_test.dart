import 'package:application/screens/login_screen.dart';
import 'package:application/screens/map_page.dart';
import 'package:application/services/helpers/background_service_helper.dart';
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

  setUp(() {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async {
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
    await sl.reset();
  });

  tearDownAll(() async {
    await HydratedBloc.storage.clear();
    await Hive.deleteFromDisk();
  });

  testWidgets('log in and navigate to profile page', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.byType(LoginScreen), findsOneWidget);

    final emailForm = find.byKey(Key('login_mail'));
    expect(emailForm, findsOneWidget);

    final passwordForm = find.byKey(Key('login_password'));
    expect(passwordForm, findsOneWidget);

    await tester.enterText(emailForm, 'integration@test.it');
    await tester.enterText(passwordForm, 'password');

    final signInButton = find.byKey(Key('login_button'));
    expect(signInButton, findsOneWidget);

    await tester.tap(signInButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byType(MapPage), findsOneWidget);
  });

  testWidgets('Logout', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await login(tester);
    await goToProfilePage(tester);

    final logoutButton = find.byKey(Key('logout_button'));
    expect(logoutButton, findsOneWidget);

    await tester.ensureVisible(logoutButton);
    await tester.tap(logoutButton);

    await tester.pumpAndSettle(const Duration(seconds: 20));

    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });
}
