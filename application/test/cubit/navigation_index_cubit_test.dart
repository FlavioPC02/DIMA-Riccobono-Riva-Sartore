import 'dart:async';

import 'package:application/core/cubit/navigation_index_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

void main() {
  setUpAll(() {
    setupTest();
  });

  group('NavigationIndexCubit', () {
    late StreamController<User?> authController;

    setUp(() {
      authController = StreamController<User?>.broadcast();
    });

    tearDown(() async {
      if (!authController.isClosed) {
        await authController.close();
      }
    });

    test('initial state is 0', () {
      final cubit = NavigationIndexCubit(
        authChanges: () => authController.stream,
      );
      expect(cubit.state, 0);
      cubit.close();
    });

    blocTest<NavigationIndexCubit, int>(
      'setIndex emits the given index',
      build: () => NavigationIndexCubit(authChanges: () => authController.stream),
      act: (cubit) => cubit.setIndex(2),
      expect: () => [2],
    );

    blocTest<NavigationIndexCubit, int>(
      'setIndex can be called multiple times, emitting each new index',
      build: () => NavigationIndexCubit(authChanges: () => authController.stream),
      act: (cubit) {
        cubit.setIndex(1);
        cubit.setIndex(3);
      },
      expect: () => [1, 3],
    );

    blocTest<NavigationIndexCubit, int>(
      'resets to 0 when the auth stream emits a null user (sign-out)',
      build: () => NavigationIndexCubit(authChanges: () => authController.stream),
      act: (cubit) async {
        cubit.setIndex(2);
        authController.add(null);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [2, 0],
    );

    blocTest<NavigationIndexCubit, int>(
      'does not emit when the auth stream emits a non-null user',
      build: () => NavigationIndexCubit(authChanges: () => authController.stream),
      act: (cubit) async {
        cubit.setIndex(1);
        authController.add(FakeUser());
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [1],
    );

    test('close cancels the auth subscription and does not throw', () async {
      final cubit = NavigationIndexCubit(
        authChanges: () => authController.stream,
      );
      await cubit.close();

      expect(() => authController.add(null), returnsNormally);
    });

    test('calling close twice does not throw', () async {
      final cubit = NavigationIndexCubit(
        authChanges: () => authController.stream,
      );

      await cubit.close();
      await expectLater(cubit.close(), completes);
    });
  });
}
