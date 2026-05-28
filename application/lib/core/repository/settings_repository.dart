import 'package:application/core/models/settings.dart';
import 'package:application/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsRepository {
  final bool Function()? hasCurrentUser;
  final DatabaseService Function()? databaseServiceFactory;

  SettingsRepository({this.hasCurrentUser, this.databaseServiceFactory});

  DatabaseService? _remoteOrNull() {
    final hasUser = hasCurrentUser != null
        ? hasCurrentUser!()
        : FirebaseAuth.instance.currentUser != null;

    if (!hasUser) {
      return null;
    }

    return databaseServiceFactory != null
        ? databaseServiceFactory!()
        : DatabaseService();
  }

  Future<Settings?> fetchRemote() async {
    final remote = _remoteOrNull();
    if (remote == null) {
      return null;
    }

    final data = await remote.fetchSettings();
    if (data == null) {
      return null;
    }

    return Settings.fromJson(data);
  }

  Future<void> saveRemote(Settings settings) async {
    final remote = _remoteOrNull();
    if (remote == null) {
      return;
    }

    await remote.saveSettings(settings.toJson());
  }

  Stream<Settings?> streamRemote() {
    final remote = _remoteOrNull();
    if (remote == null) {
      return const Stream.empty();
    }

    return remote.streamSettings().map((data) {
      if (data == null) {
        return null;
      }
      return Settings.fromJson(data);
    });
  }
}