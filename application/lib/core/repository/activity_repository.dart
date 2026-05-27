import 'package:application/core/models/activity.dart';
import 'package:application/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityRepository {
  final bool Function()? hasCurrentUser;
  final DatabaseService Function()? databaseServiceFactory;

  ActivityRepository({this.hasCurrentUser, this.databaseServiceFactory});

  DatabaseService? _remoteOrNull() {
    final hasUser = hasCurrentUser != null
        ? hasCurrentUser!()
        : FirebaseAuth.instance.currentUser != null;

    if (!hasUser) return null;

    return databaseServiceFactory != null
        ? databaseServiceFactory!()
        : DatabaseService();
  }

  Stream<List<Activity>> streamActivities() {
    final remote = _remoteOrNull();
    if (remote == null) return const Stream.empty();

    return remote.streamActivities().map((list) => list
        .map((data) => Activity.fromJson(data['id'] as String, data))
        .toList());
  }

  Future<String?> addActivity(Activity activity) async {
    final remote = _remoteOrNull();
    if (remote == null) return null;
    return remote.addActivity(activity.toJson());
  }

  Future<void> updateActivity(Activity activity) async {
    final remote = _remoteOrNull();
    if (remote == null) return;
    await remote.updateActivity(activity.id, activity.toJson());
  }

  Future<void> deleteActivity(String id) async {
    final remote = _remoteOrNull();
    if (remote == null) return;
    await remote.deleteActivity(id);
  }
}
