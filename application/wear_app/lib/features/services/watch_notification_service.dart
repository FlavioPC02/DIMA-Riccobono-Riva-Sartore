import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class WatchNotificationService {
  static FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  @visibleForTesting
  static void debugOverridePlugin(FlutterLocalNotificationsPlugin plugin) {
    _notifications = plugin;
  }

  @visibleForTesting
  static void debugResetPlugin() {
    _notifications = FlutterLocalNotificationsPlugin();
  }

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notifications.initialize(settings: initializationSettings);
    
    // Create notification channel for Wear OS
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'hike_alerts',
      'Hike Alerts',
      description: 'Notifications for off-trail and status updates',
      importance: Importance.max,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'hike_alerts',
      'Hike Alerts',
      channelDescription: 'Notifications for off-trail and status updates',
      importance: Importance.max,
      enableVibration: true,
      fullScreenIntent: true, // Useful for important alerts on watch
    );

    const notificationSettings = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationSettings,
    );
  }
}
