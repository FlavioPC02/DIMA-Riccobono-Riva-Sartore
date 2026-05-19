import 'package:application/core/models/location_point.dart';

abstract class UserLocationState{
	const UserLocationState();

	//unknown state.
	const factory UserLocationState.unknown() = _Unknown;

	//known state with the last known user position.
	const factory UserLocationState.known(LocationPoint position) = _Known;

  const factory UserLocationState.error(
    LocationPoint? lastKnownPosition,
    Object? error,
  ) = _Error;

	bool get isKnown => this is _Known;

	bool get isUnknown => this is _Unknown;

  bool get isError => this is _Error;

	T when<T>({
    required T Function() unknown, 
    required T Function(LocationPoint position) known, 
    required T Function(LocationPoint? lastKnownPosition, Object? err) error,
  }) {
		if (this is _Known) {return known((this as _Known).position);}
    else if (this is _Error) {return error((this as _Error).lastKnownPosition, (this as _Error).error);}
		return unknown();
	}
}

class _Unknown extends UserLocationState {
	const _Unknown();
}

class _Known extends UserLocationState {
	final LocationPoint position;
	const _Known(this.position);
}

class _Error extends UserLocationState {
  final LocationPoint? lastKnownPosition;
  final Object? error;
  const _Error(this.lastKnownPosition, this.error);
}