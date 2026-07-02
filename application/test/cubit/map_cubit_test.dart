import 'package:application/core/cubit/map_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapCubit', () {
    test('initial state is MapState.initial', () {
      final cubit = MapCubit();
      expect(cubit.state, MapState.initial);
      cubit.close();
    });

    blocTest<MapCubit, MapState>(
      'emits [clearSearchAndTrails, initial] when clearMap is called',
      build: () => MapCubit(),
      act: (cubit) => cubit.clearMap(),
      expect: () => [
        MapState.clearSearchAndTrails,
        MapState.initial,
      ],
    );

    blocTest<MapCubit, MapState>(
      'returns to initial state after clearMap, ready for another clearMap call',
      build: () => MapCubit(),
      act: (cubit) {
        cubit.clearMap();
        cubit.clearMap();
      },
      expect: () => [
        MapState.clearSearchAndTrails,
        MapState.initial,
        MapState.clearSearchAndTrails,
        MapState.initial,
      ],
    );
  });
}
