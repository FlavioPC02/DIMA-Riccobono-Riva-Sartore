import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hike_core/hike_core.dart';

class WatchWearSyncService {
  static const _channel = MethodChannel("hike/wear_sync"); //channel name in MainActivity, to enable data sharing between devices

  VoidCallback? onOpenNavigation;

  //Stream controllers
  final _statsController = StreamController<HikeLiveStats>.broadcast();
  final _statusController = StreamController<HikeRecordingStatus>.broadcast();

  Stream<HikeLiveStats> get statsStream => _statsController.stream;
  Stream<HikeRecordingStatus> get statusStream => _statusController.stream;

  void initalize() {
    //handles multiple calls of initialize. setMethodCallHandler replaces previously registered handlers.
    _channel.setMethodCallHandler(_handleMethodCallFromPhone);
  }

  Future<bool> shouldOpenNavigation() async {
    try{
      final result = await _channel.invokeMethod<bool>('shouldOpenNavigation');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  //Dispathces call from phone to the right stream
  Future<void> _handleMethodCallFromPhone(MethodCall call) async {
    switch (call.method) {

      case 'onStatsUpdate':
        final json = jsonDecode(call.arguments as String)  as Map<String, dynamic>;
        final stats = HikeLiveStats.fromMap(json);
        _statsController.add(stats);
        break;

      case 'onStatusChange':
        final status = HikeRecordingStatus.values.byName(call.arguments as String);
        _statusController.add(status);
        break;

      case 'openNavigationScreen':
        onOpenNavigation?.call();
        break;

      default:
        throw UnimplementedError('Method ${call.method} not implemented');
    }
  }

  Future<void> sendPause() async {
    await _channel.invokeMethod('pauseRecording');
  }

  Future<void> sendResume() async {
    await _channel.invokeMethod('resumeRecording');
  }

  Future<void> sendStop() async {
    await _channel.invokeMethod('stopRecording');
  }

  void dispose() {
    _statsController.close();
    _statusController.close();
  }
}