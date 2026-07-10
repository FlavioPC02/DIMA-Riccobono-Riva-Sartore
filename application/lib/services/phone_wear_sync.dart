import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hike_core/hike_core.dart';

class PhoneWearSyncService {
  static const _channel = MethodChannel('hike/wear_sync');

  //Callbacks for LocationCubit so it can react to watch commands
  VoidCallback? onPauseFromWatch;
  VoidCallback? onResumeFromWatch;
  VoidCallback? onStopFromWatch;

  void initialize() {
    _channel.setMethodCallHandler(handleMethodCallFromWatch);
  }

  @visibleForTesting
  Future<void> handleMethodCallFromWatch(MethodCall call) async {
    switch (call.method) {
      case 'pauseRecording':
        onPauseFromWatch?.call();
        break;

      case 'resumeRecording':
        onResumeFromWatch?.call();
        break;

      case 'stopRecording':
        onStopFromWatch?.call();
        break;

      default:
        throw UnimplementedError('Method ${call.method} not implemented');
    }
  }

  Future<void> sendStats(HikeLiveStats stats) async {
    try {
      await _channel.invokeMethod(
        'sendStatsToWatch',
        jsonEncode(stats.toMap()),
      );
    } on MissingPluginException catch (e) {
      debugPrint('[PhoneWearsync] sendStats unavailable: ${e.message}');
    } on PlatformException catch (e) {
      debugPrint('[PhoneWearsync] sendStats failed: ${e.message}');
    }
  }

  Future<void> sendStatus(HikeRecordingStatus status) async {
    try {
      await _channel.invokeMethod('sendStatusToWatch', status.name);
    } on MissingPluginException catch (e) {
      debugPrint('[PhoneWearsync] sendStatus unavailable: ${e.message}');
    } on PlatformException catch (e) {
      debugPrint('[PhoneWearsync] sendStatus failed: ${e.message}');
    }
  }

  Future<void> sendOffTrailNotification(String notification) async {
    try {
      await _channel.invokeMethod('sendOffTrailNotification', notification);
    } on MissingPluginException catch (e) {
      debugPrint(
        '[PhoneWearsync] sendOffTrailNotification unavailable: ${e.message}',
      );
    } on PlatformException catch (e) {
      debugPrint(
        '[PhoneWearsync] sendOffTrailNotification failed: ${e.message}',
      );
    }
  }

  Future<void> sendNavigationPrompt() async {
    debugPrint('[PhoneWearSync] SENDING navigation prompt');
    try {
      await _channel.invokeMethod('sendNavigationPrompt');
      debugPrint('[PhoneWearSync] SENT navigation prompt');
    } on MissingPluginException catch (e) {
      debugPrint(
        '[PhoneWearsync] sendNavigationPrompt unavailable: ${e.message}',
      );
    } on PlatformException catch (e) {
      debugPrint('[PhoneWearsync] sendNavigationPrompt failed: ${e.message}');
    }
  }
}
