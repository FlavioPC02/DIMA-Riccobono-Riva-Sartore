import 'package:application/core/models/settings.dart';
import 'package:application/core/repository/settings_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'dart:async';

class SettingsCubit extends HydratedCubit<Settings> {
  final SettingsRepository _repository;
  StreamSubscription<Settings?>? _remoteSubscription;

  SettingsCubit(this._repository)
    : super(Settings(notifications: true, ferrata: false, difficulty: 0.2)) {
    _bootstrapSync();
  }

  void updateNotifications(bool value) {
    _emitAndSync(state.copyWith(notifications: value));
  }

  void updateFerrata(bool value) {
    _emitAndSync(state.copyWith(ferrata: value));
  }

  void updateDifficulty(double value) {
    _emitAndSync(state.copyWith(difficulty: value));
  }

  Future<void> _bootstrapSync() async {
    await _remoteSubscription?.cancel();
    _remoteSubscription = null;

    final remoteSettings = await _repository.fetchRemote();
    if (remoteSettings != null) {
      emit(remoteSettings);
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

  void _emitAndSync(Settings next) {
    emit(next);
    unawaited(_repository.saveRemote(next));
  }

  // Persistence
  @override
  Settings? fromJson(Map<String, dynamic> json) {
    return Settings.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(Settings state) {
    return state.toJson();
  }

  Future<void> reset() async {
    debugPrint("Settings cubit sta RESETTANDO");
    emit(Settings(notifications: true, ferrata: false, difficulty: 1));
  }

  @override
  Future<void> close() async {
    await _remoteSubscription?.cancel();
    return super.close();
  }
}
