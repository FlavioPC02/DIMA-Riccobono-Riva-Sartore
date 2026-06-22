import 'package:application/core/models/profile.dart';
import 'package:application/core/repository/profile_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'dart:async';
import 'dart:math' as math;

class ProfileCubit extends HydratedCubit<Profile> {
  final ProfileRepository _repository;
  StreamSubscription<Profile?>? _remoteSubscription;
  StreamSubscription<User?>? _authSubscription;

  ProfileCubit(this._repository)
    : super(
        Profile(
          nickname: 'name',
          mail: 'placeholder@mail.com',
          xp: 0.0,
          level: 0,
        ),
      ) {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _onLoggedOut();
      } else {
        _onLoggedIn();
      }
    });
  }

  void _onLoggedOut() {
    _remoteSubscription?.cancel();
    _remoteSubscription = null;
    clear();
    emit(Profile(nickname: '', mail: '', xp: 0, level: 0));
  }

  Future<void> _onLoggedIn() async {
    await _remoteSubscription?.cancel();
    _remoteSubscription = null;

    if (isClosed) return;

    final remoteProfile = await _repository.fetchRemote();

    if (isClosed) return;

    if (remoteProfile != null) {
      emit(remoteProfile);
    }

    _remoteSubscription = _repository.streamRemote().listen(
      (remote) {
        if (remote != null && remote != state) {
          emit(remote);
        }
      }
    );
  }

  void updateNickname(String value) {
    _emitAndSync(state.copyWith(nickname: value));
  }

  void updateXp(double value) {
    final newLevel = _levelFromTotalXp(value);
    _emitAndSync(state.copyWith(xp: value, level: newLevel));
  }

  int _levelFromTotalXp(
    double totalXp, {
    int baseXp = 100,
    double growth = 1.2,
  }) {
    double cumulative = 0.0;
    int level = 0;

    while (true) {
      final nextLevel = level + 1;
      final xpForNextLevel = baseXp * math.pow(growth, nextLevel - 1);
      if (cumulative + xpForNextLevel <= totalXp) {
        cumulative += xpForNextLevel;
        level = nextLevel;
      } else {
        break;
      }
    }

    return level;
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
  Future<void> close() async {
    await _remoteSubscription?.cancel();
    await _authSubscription?.cancel();
    _remoteSubscription = null;
    _authSubscription = null;
    return super.close();
  }
}
