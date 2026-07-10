import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/location_point.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:application/core/repository/activity_repository.dart';
import 'package:application/firebase_options.dart';
import 'package:application/services/background_tracking_service.dart';
import 'package:application/services/notification_service.dart';
import 'package:application/services/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';

const _integrationTrailId = '10101';
const _integrationTrailName = 'Integration Test Trail';
const _integrationTrailSegments = <List<LatLng>>[
  [
    LatLng(46.0679, 11.1211),
    LatLng(46.0685, 11.1220),
    LatLng(46.0692, 11.1230),
  ],
];

List<List<TrailPoint>> _integrationTrailPoints() {
  return _integrationTrailSegments.map<List<TrailPoint>>((segment) {
    return segment.map<TrailPoint>((point) {
      return TrailPoint(lat: point.latitude, lng: point.longitude);
    }).toList();
  }).toList();
}

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
    await $.tap(notificationPermissionButton);
    await grantPendingNativePermissions($);
    await $.pumpAndSettle();
  }

  final locationPermissionButton = $('Enable location permission');
  if (locationPermissionButton.exists) {
    final permission = await Geolocator.checkPermission();
    final isAlreadyGranted =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (isAlreadyGranted) {
      await $.tap($('Ignore').first);
    } else {
      await $.tap(locationPermissionButton);
      await grantPendingNativePermissions($);
    }
    await $.pumpAndSettle();
  }

  final locationServiceButton = $('Enable location service');
  if (locationServiceButton.exists) {
    throw TestFailure(
      'Location services are disabled on the test device. Enable them before '
      'running the integration tests.',
    );
  }
}

Future<bool> grantNativePermissionIfVisible(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final isVisible = await $.platform.mobile.isPermissionDialogVisible(
    timeout: timeout,
  );
  if (isVisible) {
    await $.platform.mobile.grantPermissionWhenInUse();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await $.pump();
  }
  return isVisible;
}

Future<void> grantPendingNativePermissions(
  PatrolIntegrationTester $, {
  Duration firstTimeout = const Duration(seconds: 5),
}) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    final handled = await grantNativePermissionIfVisible(
      $,
      timeout: attempt == 0 ? firstTimeout : const Duration(seconds: 2),
    );
    if (!handled) {
      return;
    }
  }
}

Future<void> settleAfterLogin(PatrolIntegrationTester $) async {
  // Location and notification requests are triggered asynchronously when the
  // home screen mounts. Handle all native dialogs before Flutter settles.
  await grantPendingNativePermissions(
    $,
    firstTimeout: const Duration(seconds: 15),
  );
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await grantTrailifysPermission($);
}

Future<void> login(PatrolIntegrationTester $) async {
  if (FirebaseAuth.instance.currentUser != null) {
    await settleAfterLogin($);
    return;
  }

  final emailForm = $(#login_mail);
  final passwordForm = $(#login_password);

  await $.enterText(emailForm, 'integration@test.it');
  await $.enterText(passwordForm, 'password');

  final signInButton = $(#login_button);

  await $.tap(signInButton);
  await settleAfterLogin($);
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

bool isTrailDetailsUnavailable(PatrolIntegrationTester $) {
  return $('Network error. Check your connection and try again.').exists ||
      $('Trail details are temporarily unavailable. Try again later.').exists ||
      $('Informations not available.').exists;
}

bool isTrailDetailActionEnabled(PatrolIntegrationTester $, Key key) {
  final action = $(key);
  if (!action.exists) {
    return false;
  }

  final button = $.tester.widget<ElevatedButton>(action);
  return button.onPressed != null;
}

Future<Finder?> searchEnabledTrailDetailActionInNTries(
  PatrolIntegrationTester $,
  Key key, {
  int maxRetries = 8,
}) async {
  for (var attempt = 1; attempt <= maxRetries; attempt++) {
    final widget = $(key);

    if (isTrailDetailsUnavailable($)) {
      if (widget.exists) {
        final button = $.tester.widget<ElevatedButton>(widget);
        expect(button.onPressed, isNull);
      }
      return null;
    }

    if (widget.exists && isTrailDetailActionEnabled($, key)) {
      return widget;
    }

    await $.pump(const Duration(seconds: 20));
  }

  throw Exception(
    'Could not find enabled widget with key "$key" after $maxRetries attempts.',
  );
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
  await goToDiaryPage($);

  final plannedTab = $('Planned');
  await $.tap(plannedTab);
}

Future<void> goToPlanActivity(PatrolIntegrationTester $) async {
  await goToTrailDetailPage($);

  final planButton = await searchEnabledTrailDetailActionInNTries(
    $,
    Key('plan_trail'),
  );
  if (planButton == null) {
    return;
  }

  await $.tap(planButton);
  await $.pump(const Duration(seconds: 10));
}

Future<void> goToNavigatorScreen(PatrolIntegrationTester $) async {
  await goToTrailDetailPage($);

  final navigateButton = await searchEnabledTrailDetailActionInNTries(
    $,
    Key('start_tracking_trail'),
    maxRetries: 10,
  );
  if (navigateButton == null) {
    return;
  }

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

Future<({String id, String name})> seedNamedPlannedActivity() async {
  final name = 'Integration Test Hike ${DateTime.now().millisecondsSinceEpoch}';
  final activity = Activity(
    id: '',
    name: name,
    status: ActivityStatus.planned,
    date: DateTime.now().add(const Duration(days: 1)),
    trailName: _integrationTrailName,
    trailId: _integrationTrailId,
    distanceKm: 0.2,
    durationMinutes: 3,
  );
  final id = await ActivityRepository().addPlannedActivity(
    activity,
    _integrationTrailPoints(),
  );
  return (id: id, name: name);
}

Future<({String id, String name})> seedNamedPlannedActivityInApp(
  PatrolIntegrationTester $,
) async {
  final name = 'Integration Test Hike ${DateTime.now().millisecondsSinceEpoch}';
  final activity = Activity(
    id: '',
    name: name,
    status: ActivityStatus.planned,
    date: DateTime.now().add(const Duration(days: 365)),
    trailName: _integrationTrailName,
    trailId: _integrationTrailId,
    distanceKm: 0.2,
    durationMinutes: 3,
  );

  final context = $.tester.element($(Navigator).first);
  await context.read<ActivityCubit>().addPlannedActivity(
    activity,
    _integrationTrailPoints(),
  );
  await $.pump(const Duration(seconds: 1));

  return (id: activity.id, name: name);
}

Future<String> seedPlannedActivity() async {
  return (await seedNamedPlannedActivity()).id;
}

Future<void> deletePlannedActivity(String id) async {
  await ActivityRepository().deleteActivity(id);
}
