import 'package:application/services/helpers/notification_permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'gps_tracker_channel',
    'High Importance Notifications',
    importance: Importance.high,
    playSound: true,
  );

  @visibleForTesting
  static FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  @visibleForTesting
  static Future<bool> Function()? mockPermissionCheck;

  //Flag to track initialization status
  static bool _isInitialized = false;

  static Future<void> initializeNotificationService() async {
    if (_isInitialized) {
      return;
    }

    try {
      await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

      AndroidInitializationSettings initializationSettingsAndroid =
          const AndroidInitializationSettings('@mipmap/ic_launcher');

      const IOSInitializationSettings iosInitializationSettings =
          IOSInitializationSettings(
            defaultPresentAlert: true,
            defaultPresentBanner: true,
            defaultPresentList: true,
            defaultPresentSound: true,
          );

      InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: iosInitializationSettings,
      );

      await plugin.initialize(settings: initializationSettings);

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  static Future<void> dispose() async {
    _isInitialized = false;
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
    Importance importance = Importance.max,
    Priority priority = Priority.high,
    bool silent = false,
    String? payload,
    String? soundName,
  }) async {
    final notificationPermissionsEnabled = mockPermissionCheck != null 
        ? await mockPermissionCheck!() 
        : await NotificationPermissionHelper.areNotificationEnabled(); 

    if (!notificationPermissionsEnabled) {
      debugPrint('Notification skipped: notifications are not enabled.');
      return;
    }

    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
            'gps_tracker_channel',
            'High Importance Notifications',
            channelDescription: 'High Importance Notifications from App',
            icon: 'ic_bg_service_small',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
          );

      final DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
            presentAlert: !silent,
            presentBanner: !silent,
            presentList: true,
            presentBadge: !silent,
            presentSound: !silent,
            interruptionLevel: InterruptionLevel.active,
            sound: soundName,
          );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }
}
