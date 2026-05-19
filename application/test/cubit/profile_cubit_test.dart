import 'dart:async';

import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/models/profile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

MockProfileRepository createMockRepo({
  Profile? initialProfile,
  Stream<Profile?>? remoteStream,
  }) {
  final repo = MockProfileRepository();

  when(() => repo.fetchRemote()).thenAnswer((_) async => initialProfile);
  when(() => repo.streamRemote()).thenAnswer((_) => remoteStream ?? Stream.empty());
  when(() => repo.saveRemote(any())).thenAnswer((_) async {});

  return repo;
}

void main() {
	
  setUpAll(() {
    setupTest();
  });

  blocTest<ProfileCubit, Profile>(
    'update nickname test', 
    build: () => ProfileCubit(createMockRepo()),
    act: (bloc) => bloc.updateNickname('test'),
    expect: () => [
      isA<Profile>().having((p) => p.nickname, 'nickname', 'test'),
    ],
  );

  blocTest<ProfileCubit, Profile>(
    'update xp test', 
    build: () => ProfileCubit(createMockRepo()),
    act: (bloc) => bloc.updateXp(345.0),
    expect: () => [
      isA<Profile>().having((p) => p.xp, 'xp', 345.0),
    ]
  );

  blocTest<ProfileCubit, Profile>(
    'bootstrap emits initial remote Profile when available',
    build: () => ProfileCubit(
      createMockRepo(
        initialProfile: Profile(
          nickname: 'test',
          mail: 'test@mail.com',
          xp: 1.0,
        ),
      ),
    ),
    expect: () => [
      isA<Profile>()
          .having((p) => p.nickname, 'nickname', 'test')
          .having((p) => p.mail, 'mail', 'test@mail.com')
          .having((p) => p.xp, 'xp', 1.0),
    ],
  );

  blocTest<ProfileCubit, Profile>(
    'bootstrap does not emit when fetchRemote returns null',
    build: () => ProfileCubit(createMockRepo(initialProfile: null)),
    expect: () => <Matcher>[],
  );

  test('stream remote emits new value and ignores null', () async {
    final controller = StreamController<Profile?>();
    final cubit = ProfileCubit(createMockRepo(remoteStream: controller.stream));

    final emitted = <Profile>[];
    final sub = cubit.stream.listen(emitted.add);

    await Future<void>.delayed(Duration.zero);
    controller.add(Profile(nickname: 'test', mail: 'test@mail.com', xp: 200.0));
    controller.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(emitted.length, 1);
    expect(emitted.first.nickname, 'test');
    expect(emitted.first.mail, 'test@mail.com');
    expect(emitted.first.xp, 200.0);

    await sub.cancel();
    await cubit.close();
    await controller.close();
  });

  test('close cancels remote subscription', () async {
    final controller = StreamController<Profile?>();
    final cubit = ProfileCubit(createMockRepo(remoteStream: controller.stream));

    await Future<void>.delayed(Duration.zero);
    expect(controller.hasListener, true);

    await cubit.close();
    expect(controller.hasListener, false);

    await controller.close();
  });

  test('update methods persist via saveRemote', () async {
    final repo = createMockRepo();
    final cubit = ProfileCubit(repo);

    cubit.updateNickname('persistenceTest');
    cubit.updateXp(300.0);

    await Future<void>.delayed(Duration.zero);
    verify(() => repo.saveRemote(any())).called(greaterThanOrEqualTo(2));

    await cubit.close();
  });

  test('toJson and fromJson convert Profile correctly', () async {
    final cubit = ProfileCubit(createMockRepo());
    const map = {
      'nickname': 'parsingTest',
      'email': 'other@test.com',
      'xp': 700.0,
    };

    final parsed = cubit.fromJson(map);
    expect(parsed, isNotNull);
    expect(parsed!.nickname, 'parsingTest');
    expect(parsed.mail, 'other@test.com');
    expect(parsed.xp, 700.0);
    expect(cubit.toJson(parsed), map);

    await cubit.close();
  });
}