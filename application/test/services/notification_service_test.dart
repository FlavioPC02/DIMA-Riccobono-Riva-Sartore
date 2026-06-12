import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:application/services/notification_service.dart';

class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {}
class MockAndroidFlutterLocalNotificationsPlugin extends Mock implements AndroidFlutterLocalNotificationsPlugin {}

class FakeInitializationSettings extends Fake implements InitializationSettings {}
class FakeNotificationDetails extends Fake implements NotificationDetails {}
class FakeAndroidNotificationChannel extends Fake implements AndroidNotificationChannel {}

void main() {
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockAndroidFlutterLocalNotificationsPlugin mockAndroidPlugin;

  setUpAll(() {
    registerFallbackValue(FakeInitializationSettings());
    registerFallbackValue(FakeNotificationDetails());
    registerFallbackValue(FakeAndroidNotificationChannel());
  });

  setUp(() async {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    mockAndroidPlugin = MockAndroidFlutterLocalNotificationsPlugin();

    NotificationService.plugin = mockPlugin;
    
    await NotificationService.dispose();
  });

  tearDown(() {
    NotificationService.mockPermissionCheck = null;
  });

  group('initializeNotificationService', () {
    test('initializes the plugin and creates Android channel successfully', () async {
      when(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroidPlugin);
      when(() => mockAndroidPlugin.createNotificationChannel(any()))
          .thenAnswer((_) async {});
      when(() => mockPlugin.initialize(settings: any(named: 'settings'))).thenAnswer((_) async => true);

      await NotificationService.initializeNotificationService();

      verify(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()).called(1);
      verify(() => mockAndroidPlugin.createNotificationChannel(NotificationService.channel)).called(1);
      verify(() => mockPlugin.initialize(settings: any(named: 'settings'))).called(1);
    });

    test('returns early if already initialized', () async {
      when(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroidPlugin);
      when(() => mockAndroidPlugin.createNotificationChannel(any()))
          .thenAnswer((_) async {});
      when(() => mockPlugin.initialize(settings: any(named: 'settings'))).thenAnswer((_) async => true);

      await NotificationService.initializeNotificationService();
      await NotificationService.initializeNotificationService();

      verify(() => mockPlugin.initialize(settings: any(named: 'settings'))).called(1); 
    });

    test('catches and handles exceptions during initialization', () async {
      when(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenThrow(Exception('Simulated init error'));

      await NotificationService.initializeNotificationService();

      verifyNever(() => mockPlugin.initialize(settings: any(named: 'settings')));
    });
  });

  group('dispose', () {
    test('resets the initialization flag to false', () async {
      when(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroidPlugin);
      when(() => mockAndroidPlugin.createNotificationChannel(any()))
          .thenAnswer((_) async {});
      when(() => mockPlugin.initialize(settings: any(named: 'settings'))).thenAnswer((_) async => true);

      await NotificationService.initializeNotificationService();
      await NotificationService.dispose();
      await NotificationService.initializeNotificationService();

      verify(() => mockPlugin.initialize(settings: any(named: 'settings'))).called(2);
    });
  });

  group('showNotification', () {
    const tTitle = 'Test Title';
    const tBody = 'Test Body';

    test('displays the notification when permissions are granted', () async {
      NotificationService.mockPermissionCheck = () async => true;
      when(() => mockPlugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      )).thenAnswer((_) async {});

      await NotificationService.showNotification(title: tTitle, body: tBody);

      verify(() => mockPlugin.show(
        id: 0,
        title: tTitle,
        body: tBody,
        notificationDetails: any(named: 'notificationDetails'),
        payload: null,
      )).called(1);
    });

    test('aborts and does not show notification if permissions are missing', () async {
      NotificationService.mockPermissionCheck = () async => false;

      await NotificationService.showNotification(title: tTitle, body: tBody);

      verifyNever(() => mockPlugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ));
    });

    test('catches and handles exceptions during notification display', () async {
      NotificationService.mockPermissionCheck = () async => true;
      
      when(() => mockPlugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      )).thenThrow(Exception('Simulated show error'));

      await NotificationService.showNotification(title: tTitle, body: tBody);

      verify(() => mockPlugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      )).called(1);
    });
  });
}