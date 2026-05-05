import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationPermissionHelper {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<bool> requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      return await _requestAndroidPermissions();
    }
    else if (Platform.isIOS) {
      return await _requestIOSPermissions();
    }
    return true;
  }

  static Future<bool> _requestAndroidPermissions() async {
    final androidPlugin = _flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      debugPrint('Android plugin not available');
      return false;
    }

    final notificationGranted = await androidPlugin.requestNotificationsPermission();

    if (notificationGranted != true) {
      return false;
    }

    //TODO: utile anche l'exact alarm permission?
    return true;
  }

  static Future<bool> _requestIOSPermissions() async {
    final iosPlugin = _flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin == null) {
      debugPrint('IOS plugin not available');
      return false;
    }

    final granted = await iosPlugin.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return granted ?? false;
  }

  static Future<bool> areNotificationEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    } else if(Platform.isIOS){
      return true;
    }
    return false;
  }
}