import 'package:application/core/models/activity.dart';
import 'package:application/core/models/location_point.dart';
import 'package:application/core/repository/activity_repository.dart';
import 'package:application/firebase_options.dart';
import 'package:application/services/background_tracking_service.dart';
import 'package:application/services/notification_service.dart';
import 'package:application/services/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';

Future<void> appSetup() async {
  await dotenv.load(fileName: ".env");

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getApplicationDocumentsDirectory()).path,
    ),
  );

  await NotificationService.initializeNotificationService();

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(LocationPointAdapter());
  }
  await DefaultBackgroundTrackingService().initialize();
  await setupLocator();
}

Future<void> grantTrailifysPermission(PatrolIntegrationTester $) async {
  await $.pumpAndSettle();

  final notificationPermissionButton = $('Enable notification permission');
  if (notificationPermissionButton.exists) {
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.tap(notificationPermissionButton);
    await $.pumpAndSettle();
  }

  final locationPermissionButton = $('Enable location permission');
  if (locationPermissionButton.exists) {
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.tap(locationPermissionButton);
    await $.pumpAndSettle();
  }

  final locationServiceButton = $('Enable location permission');
  if (locationServiceButton.exists) {
    await $.tap(locationServiceButton);
    await $.pumpAndSettle();
  }
}

Future<void> login(PatrolIntegrationTester $) async {
  if (FirebaseAuth.instance.currentUser != null) {
    return;
  }

  final emailForm = $(#login_mail);
  final passwordForm = $(#login_password);

  await $.enterText(emailForm, 'integration@test.it');
  await $.enterText(passwordForm, 'password');

  final signInButton = $(#login_button);

  await $.tap(signInButton);
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));

  await grantTrailifysPermission($);
}

Future<void> goToProfilePage(PatrolIntegrationTester $) async {
  final profileShortcut = $('Profile');

  await $.tap(profileShortcut);
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}

Future<void> goToDiaryPage(PatrolIntegrationTester $) async {
  final diaryShortcut = $('Diary');

  await $.tap(diaryShortcut);
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}

Future<void> goToFavorites(PatrolIntegrationTester $) async {
  final favoritesShortcut = $('Favorites');

  await $.tap(favoritesShortcut);
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
}

Future<void> goToTrailDetailPage(PatrolIntegrationTester $) async {
  await goToFavorites($);

  final favoritesTrail = $(#favorite_trail);
  await $.tap(favoritesTrail.first);
  await $.pump();
}

Future<Finder> searchWidgetInNTries(
  PatrolIntegrationTester $,
  Key key, {
  int maxRetries = 8,
}) async {
  for (var attempt = 1; attempt <= maxRetries; attempt++) {
    final widget = $(key);
    final errorText = $('Network error. Check your connection and try again.');

    if (errorText.exists) {
      await $(BackButton).tap();
      await $.pumpAndSettle();
      final favoritesTrail = $(#favorite_trail);
      await $.tap(favoritesTrail.first);
      await $.pump();
    }
    if (widget.exists) {
      return widget;
    }

    await $.pump(const Duration(seconds: 20));
  }

  throw Exception(
    'Could not find widget with key "$key" after $maxRetries attempts.',
  );
}

Future<void> goToPlannedDiaryPage(PatrolIntegrationTester $) async {
  goToDiaryPage($);

  final plannedTab = $('Planned');
  await $.tap(plannedTab);
}

Future<void> goToPlanActivity(PatrolIntegrationTester $) async {
  await goToTrailDetailPage($);

  final planButton = await searchWidgetInNTries($, Key('plan_trail'));
  await $.tap(planButton);
  await $.pump(const Duration(seconds: 10));
}

Future<void> goToNavigatorScreen(PatrolIntegrationTester $) async {
  await goToTrailDetailPage($);

  final navigateButton = await searchWidgetInNTries(
    $,
    Key('start_tracking_trail'),
    maxRetries: 10,
  );
  await $.tap(navigateButton);
  await $.pump(const Duration(seconds: 10));
}

Future<void> goToActivityDetailPage(PatrolIntegrationTester $) async {
  await goToDiaryPage($);

  final plannedTab = $('Planned');
  expect(plannedTab, findsOneWidget);

  await $.tap(plannedTab);
  await $.pumpAndSettle();

  final plannedTrails = $(#activity_card);
  expect(plannedTrails, findsAtLeast(1));

  await $.tap(plannedTrails.first);
  await $.pump(const Duration(seconds: 5));
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
