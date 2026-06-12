import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:application/services/helpers/notification_permission_helper.dart';

class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {}
class MockAndroidFlutterLocalNotificationsPlugin extends Mock implements AndroidFlutterLocalNotificationsPlugin {}
class MockIOSFlutterLocalNotificationsPlugin extends Mock implements IOSFlutterLocalNotificationsPlugin {}

void main() {
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockAndroidFlutterLocalNotificationsPlugin mockAndroidPlugin;
  late MockIOSFlutterLocalNotificationsPlugin mockIOSPlugin;

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    mockAndroidPlugin = MockAndroidFlutterLocalNotificationsPlugin();
    mockIOSPlugin = MockIOSFlutterLocalNotificationsPlugin();

    NotificationPermissionHelper.plugin = mockPlugin;
  });

  tearDown(() {
    NotificationPermissionHelper.mockIsAndroid = null;
    NotificationPermissionHelper.mockIsIOS = null;
  });

  group('requestNotificationPermissions', () {
    test('returns true and requests permissions when on Android', () async {
      NotificationPermissionHelper.mockIsAndroid = true;
      NotificationPermissionHelper.mockIsIOS = false;

      when(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroidPlugin);
      when(() => mockAndroidPlugin.requestNotificationsPermission())
          .thenAnswer((_) async => true);

      final result = await NotificationPermissionHelper.requestNotificationPermissions();

      expect(result, isTrue);
      verify(() => mockAndroidPlugin.requestNotificationsPermission()).called(1);
    });

    test('returns false on Android if plugin resolution fails', () async {
      NotificationPermissionHelper.mockIsAndroid = true;
      NotificationPermissionHelper.mockIsIOS = false;

      when(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(null);

      final result = await NotificationPermissionHelper.requestNotificationPermissions();

      expect(result, isFalse);
    });

    test('returns false on Android if permission is denied', () async {
      NotificationPermissionHelper.mockIsAndroid = true;
      NotificationPermissionHelper.mockIsIOS = false;

      when(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroidPlugin);
      when(() => mockAndroidPlugin.requestNotificationsPermission())
          .thenAnswer((_) async => false);

      final result = await NotificationPermissionHelper.requestNotificationPermissions();

      expect(result, isFalse);
    });

    test('returns true and requests permissions when on iOS', () async {
      NotificationPermissionHelper.mockIsAndroid = false;
      NotificationPermissionHelper.mockIsIOS = true;

      when(() => mockPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>())
          .thenReturn(mockIOSPlugin);
      when(() => mockIOSPlugin.requestPermissions(alert: true, badge: true, sound: true))
          .thenAnswer((_) async => true);

      final result = await NotificationPermissionHelper.requestNotificationPermissions();

      expect(result, isTrue);
      verify(() => mockIOSPlugin.requestPermissions(alert: true, badge: true, sound: true)).called(1);
    });

    test('returns false on iOS if plugin resolution fails', () async {
      NotificationPermissionHelper.mockIsAndroid = false;
      NotificationPermissionHelper.mockIsIOS = true;

      when(() => mockPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>())
          .thenReturn(null);

      final result = await NotificationPermissionHelper.requestNotificationPermissions();

      expect(result, isFalse);
    });

    test('returns false on iOS if permission is denied', () async {
      NotificationPermissionHelper.mockIsAndroid = false;
      NotificationPermissionHelper.mockIsIOS = true;

      when(() => mockPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>())
          .thenReturn(mockIOSPlugin);
      when(() => mockIOSPlugin.requestPermissions(alert: true, badge: true, sound: true))
          .thenAnswer((_) async => false);

      final result = await NotificationPermissionHelper.requestNotificationPermissions();

      expect(result, isFalse);
    });

    test('returns true by default on unknown platforms', () async {
      NotificationPermissionHelper.mockIsAndroid = false;
      NotificationPermissionHelper.mockIsIOS = false;

      final result = await NotificationPermissionHelper.requestNotificationPermissions();

      expect(result, isTrue);
    });
  });

  group('areNotificationEnabled', () {
    test('returns true if notifications are enabled on Android', () async {
      NotificationPermissionHelper.mockIsAndroid = true;
      NotificationPermissionHelper.mockIsIOS = false;

      when(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroidPlugin);
      when(() => mockAndroidPlugin.areNotificationsEnabled())
          .thenAnswer((_) async => true);

      final result = await NotificationPermissionHelper.areNotificationEnabled();

      expect(result, isTrue);
    });

    test('returns false if notifications are disabled on Android', () async {
      NotificationPermissionHelper.mockIsAndroid = true;
      NotificationPermissionHelper.mockIsIOS = false;

      when(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroidPlugin);
      when(() => mockAndroidPlugin.areNotificationsEnabled())
          .thenAnswer((_) async => false);

      final result = await NotificationPermissionHelper.areNotificationEnabled();

      expect(result, isFalse);
    });

    test('returns false on Android if plugin resolution fails', () async {
      NotificationPermissionHelper.mockIsAndroid = true;
      NotificationPermissionHelper.mockIsIOS = false;

      when(() => mockPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(null);

      final result = await NotificationPermissionHelper.areNotificationEnabled();

      expect(result, isFalse);
    });

    test('returns true by default on iOS', () async {
      NotificationPermissionHelper.mockIsAndroid = false;
      NotificationPermissionHelper.mockIsIOS = true;

      final result = await NotificationPermissionHelper.areNotificationEnabled();

      expect(result, isTrue);
    });

    test('returns false by default on unknown platforms', () async {
      NotificationPermissionHelper.mockIsAndroid = false;
      NotificationPermissionHelper.mockIsIOS = false;

      final result = await NotificationPermissionHelper.areNotificationEnabled();

      expect(result, isFalse);
    });
  });
}