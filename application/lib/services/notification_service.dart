import 'package:application/services/helpers/notification_permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final AndroidNotificationChannel channel = AndroidNotificationChannel(
    'gps_tracker_channel', 
    'High Importance Notifications',
    importance: Importance.high,
    playSound: true,
  );

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  //Flag to track initialization status
  static bool _isInitialized = false;

  static Future<void> initializeNotificationService() async {
    if(_isInitialized) {
      return;
    }

    try {
      await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

      AndroidInitializationSettings initializationSettingsAndroid = 
        const AndroidInitializationSettings('@mipmap/ic_launcher');

      IOSInitializationSettings iosInitializationSettings = IOSInitializationSettings();

      InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: iosInitializationSettings,
      );

      flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

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
    final notificationPermissionsEnabled = await NotificationPermissionHelper.areNotificationEnabled(); 

    if(!notificationPermissionsEnabled) {
      return;
    }
    
    try {
      const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'High Importance Notifications from App',
          icon: 'ic_bg_service_small',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await flutterLocalNotificationsPlugin.show(
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
