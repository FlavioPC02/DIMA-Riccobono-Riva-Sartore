import 'package:application/core/models/activity.dart';
import 'package:application/core/repository/activity_repository.dart';
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

Future<void> goToTrailDetailPage(WidgetTester tester) async {
  final searchButton = find.byKey(const Key('search_trail_button'));
  await tester.tap(searchButton);
  await tester.pumpAndSettle(const Duration(seconds: 10));

  const maxRetries = 5;

  for (var attempt = 1; attempt <= maxRetries; attempt++) {
    final trail = find.byKey(const Key('found_trail'));

    if (trail.evaluate().isNotEmpty) {
      await tester.tap(trail.first);
      await tester.pump(const Duration(seconds: 10));
      return;
    }

    await tester.pump(const Duration(seconds: 2));
  }

  throw Exception(
    'Could not find widget with key "found_trail" after $maxRetries attempts.',
  );
}

Future<void> goToPlannedDiaryPage(WidgetTester tester) async {
  goToDiaryPage(tester);

  final plannedTab = find.text('Planned');
  await tester.tap(plannedTab);
}

Future<void> goToPlanActivity(WidgetTester tester) async {
  await goToTrailDetailPage(tester);

  final planButton = find.byKey(Key('plan_trail'));
  await tester.tap(planButton);
  await tester.pump(const Duration(seconds: 10));
}

Future<void> goToNavigatorScreen(WidgetTester tester) async {
  await goToTrailDetailPage(tester);

  final navigateButton = find.byKey(Key('start_tracking_trail'));
  await tester.tap(navigateButton);
  await tester.pump(const Duration(seconds: 10));
}

Future<void> goToActivityDetailPage(WidgetTester tester) async {
  await goToDiaryPage(tester);

  final plannedTab = find.text('Planned');
  expect(plannedTab, findsOneWidget);

  await tester.tap(plannedTab);
  await tester.pumpAndSettle();

  final plannedTrails = find.byKey(Key('activity_card'));
  expect(plannedTrails, findsAtLeast(1));

  await tester.tap(plannedTrails.first);
  await tester.pump(const Duration(seconds: 5));
}

Future<String> seedPlannedActivity() async {
  final activity = Activity(
    id: '',
    name: 'Test Hike',
    status: ActivityStatus.planned,
    date: DateTime.now().add(const Duration(days: 1)),
  );
  final id = await ActivityRepository().addActivity(activity);
  return id!;
}

Future<void> deletePlannedActivity(String id) async {
  await ActivityRepository().deleteActivity(id);
}
