import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';

//class BackgroundServiceHelper {
//  static final BackgroundServiceHelper _instance = BackgroundServiceHelper._internal();
//  factory BackgroundServiceHelper() => _instance;
//  BackgroundServiceHelper._internal();
//
//  bool _isInitializated = false;
//
//  Future<void> initializeService() async {
//    final service = FlutterBackgroundService(); 
//
//    if(_isInitializated) {
//      return;
//    }
//
//    await service.configure(
//      iosConfiguration: IosConfiguration(
//        autoStart: false,
//        onForeground: onStart,
//        onBackground: onIosBackground,
//      ), 
//      androidConfiguration: AndroidConfiguration(
//        onStart: onStart, 
//        autoStart: false,
//        isForegroundMode: true,
//        notificationChannelId: 'foreground',
//        initialNotificationTitle: 'Location tracking',
//        initialNotificationContent: 'Tracking is active...',
//        foregroundServiceNotificationId: 888,
//      ),
//    );
//
//    _isInitializated = true;
//  }
//
//  Future<void> startService() async {
//    try {
//      final service = FlutterBackgroundService();
//      if (!_isInitializated) {
//        await initializeService();
//      }
//      bool isRunning = await service.isRunning();
//      if(isRunning) {
//        //service already running
//        return;
//      }
//      bool hasPermission = await _requestLocationPermission();
//      if(!hasPermission) {
//        throw Exception('Location permissions required');
//      }
//      bool started = await service.startService();
//
//      if (started) {
//        await Future.delayed(Platform.isIOS
//          ? const Duration(seconds: 2)
//          : const Duration(milliseconds: 300)
//        );
//      }
//      else {
//        throw Exception('Failed to start background service');
//      }
//    } catch (e) {
//      rethrow;
//    }
//  }
//
//  Future<void> stopService() async {
//    try {
//      final service = FlutterBackgroundService();
//      bool isRunning = await service.isRunning();
//
//      if (!isRunning) {
//        return;
//      }
//      service.invoke('stopService');
//
//      int waitTime = Platform.isIOS ? 1000 : 500;
//      await Future.delayed(Duration(milliseconds: waitTime));
//    } catch (e) {
//      rethrow;
//    }
//  }
//}