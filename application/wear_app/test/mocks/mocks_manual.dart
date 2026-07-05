import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hike_core/hike_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wear_app/features/cubit/watch_location_cubit.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:wear_app/features/services/watch_wear_sync.dart';

class MockWatchWearSyncService extends Mock implements WatchWearSyncService {}
class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {}
class MockAndroidFlutterLocalNotificationsPlugin extends Mock implements AndroidFlutterLocalNotificationsPlugin {}
class MockWatchLocationCubit extends MockCubit<WatchLocationState> implements WatchLocationCubit {}

class FakeInitializationSettings extends Fake implements InitializationSettings {}
class FakeNotificationDetails extends Fake implements NotificationDetails {}
class FakeAndroidNotificationChannel extends Fake implements AndroidNotificationChannel {}
class FakeHikeLiveStats extends Fake implements HikeLiveStats {}
class FakeWatchLocationState extends Fake implements WatchLocationState {}

// Register common fallback values via a helper function
void registerAllFallbacks() {
  registerFallbackValue(FakeHikeLiveStats());
  registerFallbackValue(HikeRecordingStatus.recording);
  registerFallbackValue(FakeInitializationSettings());
  registerFallbackValue(FakeNotificationDetails());
  registerFallbackValue(FakeAndroidNotificationChannel());
  registerFallbackValue(FakeWatchLocationState());
}
