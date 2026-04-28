import 'package:application/core/models/activity.dart';
import 'package:application/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityRepository {
  DatabaseService? _remoteOrNull() {
    if (FirebaseAuth.instance.currentUser == null) return null;
    return DatabaseService();
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
