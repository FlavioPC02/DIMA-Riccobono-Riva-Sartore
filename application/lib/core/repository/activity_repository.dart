import 'dart:async';

import 'package:application/core/models/activity.dart';
import 'package:application/services/database_service.dart';
import 'package:application/services/local_activity_store.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityRepository {
  final bool Function()? hasCurrentUser;
  final DatabaseService Function()? databaseServiceFactory;
  final ActivityLocalDataSource _localStore;

  ActivityRepository({
    this.hasCurrentUser,
    this.databaseServiceFactory,
    ActivityLocalDataSource? localStore,
  }) : _localStore = localStore ?? SqliteActivityStore();

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
    final localStream = _localStore.streamActivities();
    final remote = _remoteOrNull();
    if (remote == null) return localStream;

    final remoteStream = remote.streamActivities().map(
      (list) => list
          .map((data) => Activity.fromJson(data['id'] as String, data))
          .toList(),
    );

    return _mergeActivityStreams(localStream, remoteStream, remote);
  }

  Future<String?> addActivity(Activity activity) async {
    final id = activity.id.isEmpty ? _localStore.createId() : activity.id;
    final localActivity = activity.copyWith(id: id);
    await _saveActivity(localActivity);

    return id;
  }

  Future<void> updateActivity(Activity activity) async {
    final id = activity.id.isEmpty ? _localStore.createId() : activity.id;
    final localActivity = activity.copyWith(id: id);
    await _saveActivity(localActivity);
  }

  Future<void> deleteActivity(String id) async {
    await _localStore.deleteActivity(id);

    final remote = _remoteOrNull();
    if (remote == null) return;
    await remote.deleteActivity(id);
  }

  Future<void> _saveActivity(Activity activity) async {
    final remote = _remoteOrNull();

    if (activity.status != ActivityStatus.completed) {
      await _localStore.upsertActivity(activity);
      await _trySaveRemote(activity, remote);
      return;
    }

    if (remote == null) {
      await _localStore.upsertActivity(activity);
      return;
    }

    final savedRemotely = await _trySaveRemote(activity, remote);
    if (savedRemotely) {
      await _localStore.deleteActivity(activity.id);
    } else {
      await _localStore.upsertActivity(activity);
    }
  }

  Future<bool> _trySaveRemote(
    Activity activity,
    DatabaseService? remote,
  ) async {
    if (remote == null) return false;

    try {
      await remote.updateActivity(activity.id, activity.toJson());
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Activity>> _mergeActivityStreams(
    Stream<List<Activity>> localStream,
    Stream<List<Activity>> remoteStream,
    DatabaseService remote,
  ) {
    late StreamSubscription<List<Activity>> localSubscription;
    late StreamSubscription<List<Activity>> remoteSubscription;

    List<Activity> localActivities = const [];
    List<Activity> remoteActivities = const [];

    final controller = StreamController<List<Activity>>();

    void emitMerged() {
      if (controller.isClosed) return;
      controller.add(_mergeActivities(localActivities, remoteActivities));
    }

    controller.onListen = () {
      localSubscription = localStream.listen((activities) {
        localActivities = activities;
        _syncPendingCompletedActivities(activities, remote);
        emitMerged();
      }, onError: controller.addError);

      remoteSubscription = remoteStream.listen((activities) {
        remoteActivities = activities;
        emitMerged();
      }, onError: (_) {});
    };

    controller.onCancel = () async {
      await localSubscription.cancel();
      await remoteSubscription.cancel();
    };

    return controller.stream;
  }

  void _syncPendingCompletedActivities(
    List<Activity> activities,
    DatabaseService remote,
  ) {
    for (final activity in activities) {
      if (activity.status == ActivityStatus.completed) {
        unawaited(_syncCompletedActivity(activity, remote));
      }
    }
  }

  Future<void> _syncCompletedActivity(
    Activity activity,
    DatabaseService remote,
  ) async {
    final savedRemotely = await _trySaveRemote(activity, remote);
    if (savedRemotely) {
      await _localStore.deleteActivity(activity.id);
    }
  }

  List<Activity> _mergeActivities(
    List<Activity> localActivities,
    List<Activity> remoteActivities,
  ) {
    final byId = <String, Activity>{};

    for (final activity in remoteActivities) {
      byId[activity.id] = activity;
    }

    for (final activity in localActivities) {
      byId[activity.id] = activity;
    }

    final merged = byId.values.toList();
    merged.sort((a, b) => b.date.compareTo(a.date));
    return merged;
  }
}
