import 'dart:convert';

import 'package:application/services/phone_wear_sync.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import '../utils/test_config.dart';

void main() {
  const channel = MethodChannel('hike/wear_sync');

  late List<MethodCall> sentCalls;
  late PhoneWearSyncService service;

  setUpAll(() {
    setupTest();
  });

  setUp(() {
    sentCalls = <MethodCall>[];
    service = PhoneWearSyncService();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      sentCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<dynamic> simulateIncomingCall(String method, [dynamic arguments]) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      (ByteData? data) {},
    );
  }

  group('initialize', () {
    test('registers a method call handler on the channel', () async {
      service.initialize();

      var paused = false;
      service.onPauseFromWatch = () => paused = true;

      await simulateIncomingCall('pauseRecording');

      expect(paused, isTrue);
    });

    test('calling initialize() twice replaces, not duplicates, the handler',
        () async {
      service.initialize();
      service.initialize();

      var callCount = 0;
      service.onPauseFromWatch = () => callCount++;

      await simulateIncomingCall('pauseRecording');

      expect(callCount, 1);
    });
  });

  group('incoming commands from watch', () {
    setUp(() => service.initialize());

    test('pauseRecording invokes onPauseFromWatch callback', () async {
      var called = false;
      service.onPauseFromWatch = () => called = true;

      await simulateIncomingCall('pauseRecording');

      expect(called, isTrue);
    });

    test('resumeRecording invokes onResumeFromWatch callback', () async {
      var called = false;
      service.onResumeFromWatch = () => called = true;

      await simulateIncomingCall('resumeRecording');

      expect(called, isTrue);
    });

    test('stopRecording invokes onStopFromWatch callback', () async {
      var called = false;
      service.onStopFromWatch = () => called = true;

      await simulateIncomingCall('stopRecording');

      expect(called, isTrue);
    });

    test('does not crash when a callback is null (not yet registered)',
        () async {
      expect(
        () => simulateIncomingCall('pauseRecording'),
        returnsNormally,
      );
    });

    test('unknown method throws UnimplementedError', () async {
      service.initialize();

      await expectLater(
        service.handleMethodCallFromWatch(
          const MethodCall('someUnknownMethod', null),
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('sendStats', () {
    test('invokes sendStatsToWatch with JSON-encoded stats', () async {
      final stats = HikeLiveStats(
        elapsedTime: const Duration(minutes: 12),
        distanceMeters: 1500,
        totalDistanceMeters: 5000,
        elevationGapMeters: 80,
        eta: DateTime(2026, 6, 17, 12, 30),
        isOffTrail: false,
        offTrailDirection: null,
      );

      await service.sendStats(stats);

      expect(sentCalls, hasLength(1));
      expect(sentCalls.single.method, 'sendStatsToWatch');

      final decoded = jsonDecode(sentCalls.single.arguments as String);
      expect(decoded, stats.toMap());
    });

    test('swallows PlatformException and does not rethrow', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ERROR', message: 'native failure');
      });

      final stats = HikeLiveStats.empty();

      await expectLater(service.sendStats(stats), completes);
    });
  });

  group('sendStatus', () {
    test('invokes sendStatusToWatch with the status name string', () async {
      await service.sendStatus(HikeRecordingStatus.paused);

      expect(sentCalls, hasLength(1));
      expect(sentCalls.single.method, 'sendStatusToWatch');
      expect(sentCalls.single.arguments, 'paused');
    });

    test('sends the correct string for each HikeRecordingStatus value',
        () async {
      for (final status in HikeRecordingStatus.values) {
        sentCalls.clear();
        await service.sendStatus(status);
        expect(sentCalls.single.arguments, status.name);
      }
    });

    test('swallows PlatformException and does not rethrow', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ERROR');
      });

      await expectLater(
        service.sendStatus(HikeRecordingStatus.recording),
        completes,
      );
    });
  });

  group('sendOffTrailNotification', () {
    test('invokes sendOffTrailNotification with the message string',
        () async {
      await service.sendOffTrailNotification('Move left to get back on trail');

      expect(sentCalls, hasLength(1));
      expect(sentCalls.single.method, 'sendOffTrailNotification');
      expect(
        sentCalls.single.arguments,
        'Move left to get back on trail',
      );
    });

    test('swallows PlatformException and does not rethrow', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ERROR');
      });

      await expectLater(
        service.sendOffTrailNotification('test'),
        completes,
      );
    });
  });

  group('sendNavigationPrompt', () {
    test('invokes sendNavigationPrompt with no arguments', () async {
      await service.sendNavigationPrompt();

      expect(sentCalls, hasLength(1));
      expect(sentCalls.single.method, 'sendNavigationPrompt');
      expect(sentCalls.single.arguments, isNull);
    });

    test('swallows PlatformException and does not rethrow', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ERROR');
      });

      await expectLater(service.sendNavigationPrompt(), completes);
    });
  });

  group('end-to-end roundtrip', () {
    test(
      'a full pause -> resume -> stop sequence from the watch correctly '
      'drives all three callbacks in order',
      () async {
        service.initialize();

        final callOrder = <String>[];
        service.onPauseFromWatch = () => callOrder.add('pause');
        service.onResumeFromWatch = () => callOrder.add('resume');
        service.onStopFromWatch = () => callOrder.add('stop');

        await simulateIncomingCall('pauseRecording');
        await simulateIncomingCall('resumeRecording');
        await simulateIncomingCall('stopRecording');

        expect(callOrder, ['pause', 'resume', 'stop']);
      },
    );

    test(
      'outgoing sendStats/sendStatus calls do not interfere with incoming '
      'command handling on the same channel',
      () async {
        service.initialize();

        var stopped = false;
        service.onStopFromWatch = () => stopped = true;

        await service.sendStatus(HikeRecordingStatus.recording);
        await simulateIncomingCall('stopRecording');

        expect(stopped, isTrue);
        expect(sentCalls.map((c) => c.method), contains('sendStatusToWatch'));
      },
    );
  });
}
