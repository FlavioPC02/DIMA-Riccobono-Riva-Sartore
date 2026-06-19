import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> login(WidgetTester tester) async {
  if (FirebaseAuth.instance.currentUser != null) {
    return;
  }

  final emailForm = find.byKey(Key('login_mail'));
  final passwordForm = find.byKey(Key('login_password'));

  await tester.enterText(emailForm, 'integration@test.it');
  await tester.enterText(passwordForm, 'password');

  final signInButton = find.byKey(Key('login_button'));

  await tester.tap(signInButton);
  await tester.pumpAndSettle(const Duration(seconds: 10));
}

Future<void> goToProfilePage(WidgetTester tester) async {
  final profileShortcut = find.text('Profile');

  await tester.tap(profileShortcut);
  await tester.pumpAndSettle(const Duration(seconds: 10));
}

Future<void> goToDiaryPage(WidgetTester tester) async {
  final diaryShortcut = find.text('Diary');

  await tester.tap(diaryShortcut);
  await tester.pumpAndSettle(const Duration(seconds: 10));
}

Future<void> goToFavorites(WidgetTester tester) async {
  final favoritesShortcut = find.text('Favorites');

  await tester.tap(favoritesShortcut);
  await tester.pumpAndSettle(const Duration(seconds: 10));
}
