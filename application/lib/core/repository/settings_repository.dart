import 'package:application/core/models/settings.dart';
import 'package:application/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsRepository {
  DatabaseService? _remoteOrNull() {
    if (FirebaseAuth.instance.currentUser == null) {
      return null;
    }
    return DatabaseService();
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