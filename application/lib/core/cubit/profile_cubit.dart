import 'package:application/core/models/profile.dart';
import 'package:application/core/repository/profile_repository.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'dart:async';

class ProfileCubit extends HydratedCubit<Profile> {
  final ProfileRepository _repository;
  StreamSubscription<Profile?>? _remoteSubscription;

  ProfileCubit(this._repository)
    : super(Profile(
      nickname: 'name', 
      mail: 'placeholder@mail.com', 
      xp: 0.0)
    ) {
      _bootstrapSync();
    }

  void updateNickname(String value) {
    _emitAndSync(state.copyWith(nickname: value));
  }

  void updateXp(double value) {
    _emitAndSync(state.copyWith(xp: value));
  }

  Future<void> _bootstrapSync() async {
    final remoteProfile = await _repository.fetchRemote();
    if (remoteProfile != null) {
      emit(remoteProfile);
    }

    _remoteSubscription = _repository.streamRemote().listen((remote) {
      if (remote != null && remote != state) {
        emit(remote);
      }
    });
  }

  void _emitAndSync(Profile next) {
    emit(next);
    unawaited(_repository.saveRemote(next));
  }

  // Persistence
  @override
  Profile? fromJson(Map<String, dynamic> json) {
    return Profile.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(Profile state) {
    return state.toJson();
  }

  @override
  Future<void> close() {
    _remoteSubscription?.cancel();
    return super.close();
  }
}