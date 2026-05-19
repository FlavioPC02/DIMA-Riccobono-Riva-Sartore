import 'dart:io';

import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/profile.dart';
import 'package:application/core/models/settings.dart';
import 'package:application/core/repository/profile_repository.dart';
import 'package:application/core/repository/settings_repository.dart';
import 'package:application/services/auth_service.dart';
import 'package:application/services/database_service.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockSettingsCubit extends Mock implements SettingsCubit {}
class MockProfileCubit extends Mock implements ProfileCubit {}
class MockAuthService extends Mock implements AuthService {}
class MockDatabaseService extends Mock implements DatabaseService {}
class MockSettingsRepository extends Mock implements SettingsRepository {}
class MockProfileRepository extends Mock implements ProfileRepository {}

class MockSettings extends Mock implements Settings {}

class MockHttpClient extends Mock implements HttpClient {}
class MockHttpClientRequest extends Mock implements HttpClientRequest {}
class MockHttpClientResponse extends Mock implements HttpClientResponse {}
class MockHttpHeaders extends Mock implements HttpHeaders {}

// Fakes for fallback registration
class FakeSettings extends Fake implements Settings {}
class FakeProfile extends Fake implements Profile {}
class FakeDuration extends Fake implements Duration {}
class FakeHttpClientRequest extends Fake implements HttpClientRequest {}
class FakeUri extends Fake implements Uri {}

// Register common fallback values via a helper function
void registerAllFallbacks() {
	registerFallbackValue(FakeSettings());
	registerFallbackValue(FakeProfile());
	registerFallbackValue(FakeDuration());
	registerFallbackValue(FakeHttpClientRequest());
	registerFallbackValue(FakeUri());
}
