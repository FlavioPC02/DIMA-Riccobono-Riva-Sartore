import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/settings.dart';
import 'package:application/core/repository/settings_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../utils/test_config.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

MockSettingsRepository createMockRepo({
  Settings? initialSettings,
}) {
  final repo = MockSettingsRepository();

    // Configure mock to return null for fetchRemote
    when(repo.fetchRemote()).thenAnswer(
      (_) async => initialSettings ?? 
        Settings(
          notifications: true, 
          ferrata: true, 
          difficulty: 1,
        ),
    );
    
    // Configure mock to return empty stream for streamRemote
    when(repo.streamRemote()).thenAnswer((_) => Stream.empty());
    
    // Configure mock for saveRemote to complete successfully
    //when(repo.saveRemote(any)).thenAnswer((_) async {});

    return repo;
}

void main() {

  setUpAll(() {
    setupTest();
  });

  blocTest<SettingsCubit, Settings>(
    'update notifications test', 
    build: () => SettingsCubit(createMockRepo()),
    act: (cubit) => cubit.updateNotifications(false),
    expect: () => [
      isA<Settings>().having((s) => s.notifications, 'notifications', false),
    ],
  );
}