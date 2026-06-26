import 'package:application/core/models/settings.dart';
import 'package:application/core/repository/settings_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'dart:async';

class SettingsCubit extends HydratedCubit<Settings> {
  final SettingsRepository _repository;
  final Stream<User?> Function()? authChanges; //injectable for test
  StreamSubscription<Settings?>? _remoteSubscription;
  StreamSubscription<User?>? _authSubscription;

  SettingsCubit(this._repository, {this.authChanges})
    : super(Settings(notifications: true, ferrata: false, difficulty: 0)) {
    final stream = authChanges != null
        ? authChanges!()
        : FirebaseAuth.instance.authStateChanges();
    _authSubscription = stream.listen((user) {
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
    emit(Settings(notifications: true, ferrata: false, difficulty: 0));
  }

  Future<void> _onLoggedIn() async {
    await _remoteSubscription?.cancel();
    _remoteSubscription = null;

    if (isClosed) return;

    final remoteSettings = await _repository.fetchRemote();

    if (isClosed) return;

    if (remoteSettings != null) {
      emit(remoteSettings);
    }

    _remoteSubscription = _repository.streamRemote().listen((remote) {
      if (remote != null && remote != state) {
        emit(remote);
      }
    });
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

  @override
  Future<void> close() async {
    await _remoteSubscription?.cancel();
    await _authSubscription?.cancel();
    _remoteSubscription = null;
    _authSubscription = null;
    return super.close();
  }
}
