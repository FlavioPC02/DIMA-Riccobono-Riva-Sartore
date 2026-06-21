import 'package:application/core/models/profile.dart';
import 'package:application/core/repository/profile_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'dart:async';
import 'dart:math' as math;

class ProfileCubit extends HydratedCubit<Profile> {
  final ProfileRepository _repository;
  StreamSubscription<Profile?>? _remoteSubscription;

  ProfileCubit(this._repository)
    : super(
        Profile(
          nickname: 'name',
          mail: 'placeholder@mail.com',
          xp: 0.0,
          level: 0,
        ),
      ) {
    _bootstrapSync();
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

  Future<void> _bootstrapSync() async {
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
      },
      onError: (e) {
        if (e is FirebaseException && e.code == 'permission-denied') {
          return;
        }
      },
    );
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

  Future<void> reset() async {
    debugPrint("Profile cubit sta RESETTANDO");
    await _remoteSubscription?.cancel();
    _remoteSubscription = null;

    emit(Profile(nickname: '', mail: '', xp: 0, level: 0));
  }

  @override
  Future<void> close() async {
    debugPrint("Profile cubit sta CHIUDENDO");
    await _remoteSubscription?.cancel();
    _remoteSubscription = null;
    return super.close();
  }
}
