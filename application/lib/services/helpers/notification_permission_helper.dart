import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationPermissionHelper {
  @visibleForTesting
  static FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  @visibleForTesting
  static bool? mockIsAndroid;
  @visibleForTesting
  static bool? mockIsIOS;

  static bool get _isAndroid => mockIsAndroid ?? Platform.isAndroid;
  static bool get _isIOS => mockIsIOS ?? Platform.isIOS;

  static Future<bool> requestNotificationPermissions() async {
    if (_isAndroid) {
      return await _requestAndroidPermissions();
    }
    else if (_isIOS) {
      return await _requestIOSPermissions();
    }
    return true;
  }

  static Future<bool> _requestAndroidPermissions() async {
    final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
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
    final iosPlugin = plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin == null) {
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
    if (_isAndroid) {
      final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    } else if(_isIOS){
      return true;
    }
    return false;
  }
}