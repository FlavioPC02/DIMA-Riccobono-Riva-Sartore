import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import 'package:wear_app/features/services/watch_wear_sync.dart';

void main() {
  const channel = MethodChannel('hike/wear_sync');

  late List<MethodCall> sentCalls;
  late WatchWearSyncService service;

  setUp(() {
    sentCalls = <MethodCall>[];
    service = WatchWearSyncService();

    TestWidgetsFlutterBinding.ensureInitialized();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      sentCalls.add(call);
      if (call.method == 'shouldOpenNavigation') return false;
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

  group('initalize (sic) and incoming dispatch', () {
    setUp(() => service.initalize());

    test('onStatsUpdate decodes JSON and emits on statsStream', () async {
      final stats = HikeLiveStats(
        elapsedTime: const Duration(minutes: 4),
        distanceMeters: 800,
        totalDistanceMeters: 4000,
        elevationGapMeters: 30,
        eta: DateTime(2026, 6, 17, 13, 0),
        isOffTrail: false,
        offTrailDirection: null,
      );

      final received = <HikeLiveStats>[];
      final sub = service.statsStream.listen(received.add);

      await simulateIncomingCall(
        'onStatsUpdate',
        jsonEncode(stats.toMap()),
      );
      // Let the stream's microtask queue flush.
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single, stats);

      await sub.cancel();
    });

    test('onStatusChange parses the status name and emits on statusStream',
        () async {
      final received = <HikeRecordingStatus>[];
      final sub = service.statusStream.listen(received.add);

      await simulateIncomingCall('onStatusChange', 'paused');
      await Future<void>.delayed(Duration.zero);

      expect(received, [HikeRecordingStatus.paused]);

      await sub.cancel();
    });

    test('openNavigationScreen invokes onOpenNavigation callback', () async {
      var called = false;
      service.onOpenNavigation = () => called = true;

      await simulateIncomingCall('openNavigationScreen');

      expect(called, isTrue);
    });

    test('onOffTrailNotification forwards the message string to the '
        'registered callback', () async {
      String? received;
      service.onOffTrailNotification = (msg) => received = msg;

      await simulateIncomingCall(
        'onOffTrailNotification',
        'Move left to get back on trail',
      );

      expect(received, 'Move left to get back on trail');
    });

    test('unknown method throws UnimplementedError', () async {
      await expectLater(
        service.handleMethodCallFromPhone(
          const MethodCall('someUnknownMethod', null),
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('calling initalize() twice does not duplicate stream emissions',
        () async {
      service.initalize(); // second call

      final received = <HikeRecordingStatus>[];
      final sub = service.statusStream.listen(received.add);

      await simulateIncomingCall('onStatusChange', 'recording');
      await Future<void>.delayed(Duration.zero);

      expect(received, [HikeRecordingStatus.recording]);

      await sub.cancel();
    });
  });

  group('shouldOpenNavigation', () {
    test('returns true when Kotlin responds true', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'shouldOpenNavigation') return true;
        return null;
      });

      final result = await service.shouldOpenNavigation();

      expect(result, isTrue);
    });

    test('returns false when Kotlin responds false', () async {
      final result = await service.shouldOpenNavigation();
      expect(result, isFalse);
    });

    test('returns false when Kotlin responds null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      final result = await service.shouldOpenNavigation();

      expect(result, isFalse);
    });

    test('returns false and swallows PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ERROR');
      });

      final result = await service.shouldOpenNavigation();

      expect(result, isFalse);
    });
  });

  group('outgoing commands', () {
    test('sendPause invokes pauseRecording with no arguments', () async {
      await service.sendPause();

      expect(sentCalls, hasLength(1));
      expect(sentCalls.single.method, 'pauseRecording');
    });

    test('sendResume invokes resumeRecording with no arguments', () async {
      await service.sendResume();

      expect(sentCalls, hasLength(1));
      expect(sentCalls.single.method, 'resumeRecording');
    });

    test('sendStop invokes stopRecording with no arguments', () async {
      await service.sendStop();

      expect(sentCalls, hasLength(1));
      expect(sentCalls.single.method, 'stopRecording');
    });
  });

  group('dispose', () {
    test('closes both stream controllers', () async {
      service.initalize();

      service.dispose();

      expect(service.statsStream.isBroadcast, isTrue);
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
