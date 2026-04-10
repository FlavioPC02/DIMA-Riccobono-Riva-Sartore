import 'package:application/core/models/profile.dart';
import 'package:application/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileRepository {
  DatabaseService? _remoteOrNull() {
    if (FirebaseAuth.instance.currentUser == null) {
      return null;
    }
    return DatabaseService();
  }

  Future<Profile?> fetchRemote() async {
    final remote = _remoteOrNull();
    if (remote == null) {
      return null;
    }

    final data = await remote.fetchProfile();
    if (data == null) {
      return null;
    }

    return Profile.fromJson(data);
  }

  Future<void> saveRemote(Profile settings) async {
    final remote = _remoteOrNull();
    if (remote == null) {
      return;
    }

    await remote.saveProfile(settings.toJson());
  }

  Stream<Profile?> streamRemote() {
    final remote = _remoteOrNull();
    if (remote == null) {
      return const Stream.empty();
    }

    return remote.streamProfile().map((data) {
      if (data == null) {
        return null;
      }
      return Profile.fromJson(data);
    });
  }
}