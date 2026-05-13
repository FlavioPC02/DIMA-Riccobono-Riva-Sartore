import 'dart:async';

import 'package:application/core/models/user_location_state.dart';
import 'package:application/core/models/user_position.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' as geo;

class UserLocationCubit extends Cubit<UserLocationState>{
  UserLocationCubit() : super(const UserLocationState.unknown()) {
    listenUpdates();
  }

  StreamSubscription? _positionSubscription;
  UserPosition? _lastKnownPosition;

  void listenUpdates() {
    _positionSubscription = geo.Geolocator
      .getPositionStream()
      .listen((position) {
        final userPosition = UserPosition(
          position: LatLng(position.latitude, position.longitude), 
          positionAccuracy: position.accuracy, 
          altitude: position.altitude, 
          altitudeAccuracy: position.altitudeAccuracy,
        );
        emit(UserLocationState.known(userPosition));
        _lastKnownPosition = userPosition;
      })
      ..onError((error, stackTrace) {
        emit(UserLocationState.error(_lastKnownPosition, error));
      });
  }

  @override 
  Future<void> close() {
    _positionSubscription?.cancel();
    return super.close();
  }
}