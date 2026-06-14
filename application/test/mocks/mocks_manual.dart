import 'dart:io';

import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/location_point.dart';
import 'package:application/core/models/profile.dart';
import 'package:application/core/models/settings.dart';
import 'package:application/core/repository/location_repository.dart';
import 'package:application/core/repository/activity_repository.dart';
import 'package:application/core/repository/profile_repository.dart';
import 'package:application/core/repository/settings_repository.dart';
import 'package:application/services/background_tracking_service.dart';
import 'package:application/services/auth_service.dart';
import 'package:application/services/database_service.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockSettingsCubit extends Mock implements SettingsCubit {}
class MockProfileCubit extends Mock implements ProfileCubit {}
class MockActivityCubit extends Mock implements ActivityCubit {}
class MockAuthService extends Mock implements AuthService {}
class MockDatabaseService extends Mock implements DatabaseService {}
class MockActivityRepository extends Mock implements ActivityRepository {}
class MockSettingsRepository extends Mock implements SettingsRepository {}
class MockProfileRepository extends Mock implements ProfileRepository {}
class MockLocationRepository extends Mock implements ILocationRepository {}
class MockBackgroundTrackingService extends Mock implements BackgroundTrackingService {}

class MockSettings extends Mock implements Settings {}

class MockHttpClient extends Mock implements HttpClient {}
class MockHttpClientRequest extends Mock implements HttpClientRequest {}
class MockHttpClientResponse extends Mock implements HttpClientResponse {}
class MockHttpHeaders extends Mock implements HttpHeaders {}

// Fakes for fallback registration
class FakeActivity extends Fake implements Activity {}
class FakeSettings extends Fake implements Settings {}
class FakeProfile extends Fake implements Profile {}
class FakeDuration extends Fake implements Duration {}
class FakeLocationPoint extends Fake implements LocationPoint {}
class FakeHttpClientRequest extends Fake implements HttpClientRequest {}
class FakeUri extends Fake implements Uri {}

// Hive mocks
class MockBox extends Mock implements Box<LocationPoint> {}

// Register common fallback values via a helper function
void registerAllFallbacks() {
	registerFallbackValue(FakeActivity());
	registerFallbackValue(FakeSettings());
	registerFallbackValue(FakeProfile());
	registerFallbackValue(FakeDuration());
	registerFallbackValue(FakeLocationPoint());
	registerFallbackValue(FakeHttpClientRequest());
	registerFallbackValue(FakeUri());
}