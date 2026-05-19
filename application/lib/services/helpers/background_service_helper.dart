import 'dart:async';
import 'dart:ui';

import 'package:application/services/location_engine.dart';
import 'package:application/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

class BackgroundServiceHelper {
	BackgroundServiceHelper._internal();

	static final BackgroundServiceHelper instance = BackgroundServiceHelper._internal();

	Future<bool> requestBackgroundPermissions() async {
		debugPrint('BackgroundServiceHelper: requesting background permissions');

		try {
			final locationPermission = await Geolocator.requestPermission();
			if (locationPermission == LocationPermission.denied ||
					locationPermission == LocationPermission.deniedForever) {
				debugPrint('BackgroundServiceHelper: location permission denied');
				return false;
			}

			debugPrint('BackgroundServiceHelper: fine location permission granted: $locationPermission');

			if (locationPermission == LocationPermission.whileInUse) {
				debugPrint('BackgroundServiceHelper: requesting background location permission');
				await Geolocator.openLocationSettings();
			}

			return true;
		} catch (e) {
			debugPrint('BackgroundServiceHelper: permission request error: $e');
			return false;
		}
	}

	Future<void> initializeService() async {
		debugPrint('BackgroundServiceHelper: initializeService called');
		final service = FlutterBackgroundService();

		await service.configure(
			iosConfiguration: IosConfiguration(
				autoStart: false,
				onForeground: onStart,
			),
			androidConfiguration: AndroidConfiguration(
				onStart: onStart,
				autoStart: false,
				isForegroundMode: true,
				notificationChannelId: NotificationService.channel.id,
				initialNotificationTitle: 'Trailfy tracking is active',
				initialNotificationContent: 'Background GPS monitoring',
				foregroundServiceNotificationId: 888,
			),
		);
	}
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
	debugPrint('BackgroundServiceHelper: onStart entry');

	try {
		DartPluginRegistrant.ensureInitialized();

		final directory = await getApplicationDocumentsDirectory();
		Hive.init(directory.path);
		await Hive.openBox('location_box');
		debugPrint('BackgroundServiceHelper: hive box opened');

		final engine = LocationEngine.background();
		await engine.start();
		debugPrint('BackgroundServiceHelper: background engine started');

		final keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
			debugPrint('BackgroundServiceHelper: keep-alive ping (${DateTime.now()})');
		});

		service.on('stopService').listen((event) async {
			keepAliveTimer.cancel();
			await engine.stop();
			debugPrint('BackgroundServiceHelper: service stopped');
			service.stopSelf();
		});
	} catch (e, st) {
		debugPrint('BackgroundServiceHelper error: $e');
		debugPrintStack(stackTrace: st, label: 'BackgroundServiceHelper');
	}
}