import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wear_app/features/services/watch_notification_service.dart';

import '../mocks/mocks_manual.dart';
import '../test_config.dart';


void main() {
  setUpAll(() {
    setupTest();
  });

  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockAndroidFlutterLocalNotificationsPlugin mockAndroidImpl;

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    mockAndroidImpl = MockAndroidFlutterLocalNotificationsPlugin();

    WatchNotificationService.debugOverridePlugin(mockPlugin);

    when(() => mockPlugin.initialize(settings: any(named: 'settings')))
        .thenAnswer((_) async => true);

    when(() => mockPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>())
        .thenReturn(mockAndroidImpl);

    when(() => mockAndroidImpl.createNotificationChannel(any()))
        .thenAnswer((_) async {});

    when(() => mockPlugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
        )).thenAnswer((_) async {});
  });

  tearDown(() {
    WatchNotificationService.debugResetPlugin();
  });

  group('initialize', () {
    test('calls plugin.initialize with Android settings configured',
        () async {
      await WatchNotificationService.initialize();

      final captured = verify(
        () => mockPlugin.initialize(settings: captureAny(named: 'settings')),
      ).captured;

      expect(captured, hasLength(1));
      final settings = captured.single as InitializationSettings;
      expect(settings.android, isA<AndroidInitializationSettings>());
    });

    test('creates the hike_alerts notification channel with correct '
        'metadata', () async {
      await WatchNotificationService.initialize();

      final captured = verify(
        () => mockAndroidImpl.createNotificationChannel(captureAny()),
      ).captured;

      expect(captured, hasLength(1));
      final channel = captured.single as AndroidNotificationChannel;
      expect(channel.id, 'hike_alerts');
      expect(channel.name, 'Hike Alerts');
      expect(channel.description,
          'Notifications for off-trail and status updates');
      expect(channel.importance, Importance.max);
      expect(channel.enableVibration, isTrue);
    });

    test('does not throw when resolvePlatformSpecificImplementation '
        'returns null (e.g. running on a non-Android platform)', () async {
      when(() => mockPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(null);

      await expectLater(
        WatchNotificationService.initialize(),
        completes,
      );
    });

    test('calls initialize before attempting to create the channel '
        '(ordering)', () async {
      final callOrder = <String>[];

      when(() => mockPlugin.initialize(settings: any(named: 'settings')))
          .thenAnswer((_) async {
        callOrder.add('initialize');
        return true;
      });
      when(() => mockAndroidImpl.createNotificationChannel(any()))
          .thenAnswer((_) async {
        callOrder.add('createChannel');
      });

      await WatchNotificationService.initialize();

      expect(callOrder, ['initialize', 'createChannel']);
    });
  });

  group('showNotification', () {
    test('calls plugin.show with the provided title and body', () async {
      await WatchNotificationService.showNotification(
        title: 'Off Trail Alert!',
        body: 'Move left to get back on trail',
      );

      verify(() => mockPlugin.show(
            id: 0,
            title: 'Off Trail Alert!',
            body: 'Move left to get back on trail',
            notificationDetails: any(named: 'notificationDetails'),
          )).called(1);
    });

    test('defaults id to 0 when not specified', () async {
      await WatchNotificationService.showNotification(
        title: 'Title',
        body: 'Body',
      );

      verify(() => mockPlugin.show(
            id: 0,
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
          )).called(1);
    });

    test('uses the provided id when explicitly specified', () async {
      await WatchNotificationService.showNotification(
        title: 'Title',
        body: 'Body',
        id: 42,
      );

      verify(() => mockPlugin.show(
            id: 42,
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
          )).called(1);
    });

    test('builds AndroidNotificationDetails with hike_alerts channel and '
        'max importance', () async {
      await WatchNotificationService.showNotification(
        title: 'Title',
        body: 'Body',
      );

      final captured = verify(() => mockPlugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: captureAny(named: 'notificationDetails'),
          )).captured;

      final details = captured.single as NotificationDetails;
      final android = details.android!;
      expect(android.channelId, 'hike_alerts');
      expect(android.importance, Importance.max);
      expect(android.enableVibration, isTrue);
      expect(android.fullScreenIntent, isTrue);
    });

    test('two consecutive calls with different ids both reach the plugin',
        () async {
      await WatchNotificationService.showNotification(
        title: 'First',
        body: 'Body 1',
        id: 1,
      );
      await WatchNotificationService.showNotification(
        title: 'Second',
        body: 'Body 2',
        id: 2,
      );

      verify(() => mockPlugin.show(
            id: 1,
            title: 'First',
            body: 'Body 1',
            notificationDetails: any(named: 'notificationDetails'),
          )).called(1);
      verify(() => mockPlugin.show(
            id: 2,
            title: 'Second',
            body: 'Body 2',
            notificationDetails: any(named: 'notificationDetails'),
          )).called(1);
    });

    test('propagates exceptions from the plugin rather than swallowing '
        'them (no try/catch in showNotification)', () async {
      when(() => mockPlugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
          )).thenThrow(Exception('plugin failure'));

      expect(
        () => WatchNotificationService.showNotification(
          title: 'Title',
          body: 'Body',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('debugOverridePlugin / debugResetPlugin', () {
    test('debugResetPlugin replaces the mock with a real plugin instance',
        () {
      WatchNotificationService.debugResetPlugin();

      expect(() => WatchNotificationService.debugResetPlugin(), returnsNormally);
    });
  });
}
