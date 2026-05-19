import 'dart:async';

import 'package:application/core/models/location_point.dart';
import 'package:application/core/models/user_location_state.dart';
import 'package:application/core/repository/location_repository.dart';
import 'package:application/services/location_engine.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class LocationCubit extends Cubit<UserLocationState> {

  final LocationEngine engine;
  StreamSubscription<LocationPoint>? _sub;

  LocationCubit({
    required this.engine,
  }) : super(UserLocationState.unknown());


  Future<void> startForegroundTracking() async {
    try {
      await engine.start();
      await _sub?.cancel();

      _sub = engine.stream.listen(
        (point) {
          emit(UserLocationState.known(point),);
        },
        onError: (err) {
          LocationPoint? lastKnown;
          state.when(
            unknown: () {}, 
            known: (position) {
              lastKnown = position;
            }, 
            error: (_, _) {},
          );
          
          emit(
            UserLocationState.error(
              lastKnown, 
              err,
            ),
          );
        }
      );
    } catch (e) {
      emit(
        UserLocationState.error(null, e)
      );
    }
  }

  Future<void> stopTracking() async {
    await engine.stop();
    await _sub?.cancel();
    LocationRepository.clearRoute();

    emit(const UserLocationState.unknown());
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await engine.close();
    await super.close();
  }
}