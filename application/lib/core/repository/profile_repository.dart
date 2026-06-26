import 'package:application/core/models/profile.dart';
import 'package:application/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

class ProfileRepository {
  final bool Function()? hasCurrentUser;
  final DatabaseService Function()? databaseServiceFactory;
  final Stream<User?> Function()? authChanges;

  ProfileRepository({
    this.hasCurrentUser, 
    this.databaseServiceFactory,
    this.authChanges,
  });

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
    final authStream = authChanges != null
      ? authChanges!()
      : FirebaseAuth.instance.authStateChanges();

    return authStream.switchMap((user) {
      if (user == null) {
        return Stream<Profile?>.value(null);
      }

      final remote = databaseServiceFactory != null
        ? databaseServiceFactory!()
        : DatabaseService();

      return remote.streamProfile().map((data) {
        if (data == null) return null;
        return Profile.fromJson(data);
      });
    });
  }
}