import 'dart:async';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/activity_note.dart';
import 'package:application/services/database_service.dart';
import 'package:application/services/local_activity_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:application/services/planned_trail_store.dart';
import 'package:application/core/models/planned_trail.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:application/services/trail_geometry_service.dart';
import 'package:rxdart/rxdart.dart';

class ActivityRepository {
  final bool Function()? hasCurrentUser;
  final DatabaseService Function()? databaseServiceFactory;
  final Stream<User?> Function()? authChanges;
  final ActivityLocalDataSource _localStore;
  final PlannedTrailLocalDataSource _plannedTrailStore;
  final TrailGeometryDataSource _trailGeometrySource;
  final Set<String> _trailSyncInProgress = {};

  ActivityRepository({
    this.hasCurrentUser,
    this.databaseServiceFactory,
    this.authChanges,
    ActivityLocalDataSource? localStore,
    PlannedTrailLocalDataSource? plannedTrailStore,
    TrailGeometryDataSource? trailGeometrySource,
  }) : _localStore = localStore ?? HiveActivityStore(),
       _plannedTrailStore = plannedTrailStore ?? PlannedTrailStore(),
       _trailGeometrySource =
           trailGeometrySource ?? OverpassTrailGeometryService();

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
    final authStream = authChanges != null
        ? authChanges!()
        : FirebaseAuth.instance.authStateChanges();

    final remoteStream = authStream.switchMap((user) {
      if (user == null) {
        return Stream<List<Activity>>.value(const []);
      }

      final remote = databaseServiceFactory != null
          ? databaseServiceFactory!()
          : DatabaseService();

      return remote.streamActivities().map(
        (list) => list
            .map((data) => Activity.fromJson(data['id'] as String, data))
            .toList(),
      );
    });

    return _mergeActivityStreams(localStream, authStream, remoteStream);
  }

  Future<PlannedTrail?> getPlannedTrail(String activityId) async {
    return await _plannedTrailStore.getTrail(activityId);
  }

  Stream<Set<String>> watchDownloadedTrailIds() {
    return _plannedTrailStore.watchDownloadedTrailIds();
  }

  Future<void> cachePlannedTrail(
    String activityId,
    String trailId,
    List<List<TrailPoint>> trailPoints,
  ) async {
    final hasGeometry = trailPoints.any((segment) => segment.isNotEmpty);

    if (activityId.isEmpty || !hasGeometry) {
      return;
    }

    final plannedTrail = PlannedTrail(
      activityId: activityId,
      trailId: trailId,
      segments: trailPoints,
    );

    await _plannedTrailStore.saveTrail(plannedTrail);
  }

  Future<void> syncPlannedActivitiesForOffline(
    List<Activity> activities,
  ) async {
    for (final activity in activities) {
      if (activity.status != ActivityStatus.planned ||
          activity.id.isEmpty ||
          activity.trailId.isEmpty) {
        continue;
      }

      if (!_trailSyncInProgress.add(activity.id)) {
        continue;
      }

      try {
        final localActivity = await _findLocalActivity(activity.id);

        if (localActivity == null) {
          await _localStore.upsertActivity(activity);
        }

        final cachedTrail = await _plannedTrailStore.getTrail(activity.id);

        final hasCachedGeometry =
            cachedTrail?.segments.any((segment) => segment.isNotEmpty) ?? false;

        if (hasCachedGeometry) {
          continue;
        }

        final segments = await _trailGeometrySource.fetchTrailPath(
          activity.trailId,
        );

        final hasDownloadedGeometry = segments.any(
          (segment) => segment.isNotEmpty,
        );

        if (!hasDownloadedGeometry) {
          continue;
        }

        final trailPoints = segments.map<List<TrailPoint>>((segment) {
          return segment.map<TrailPoint>((point) {
            return TrailPoint(lat: point.latitude, lng: point.longitude);
          }).toList();
        }).toList();

        await cachePlannedTrail(activity.id, activity.trailId, trailPoints);
      } catch (_) {
        // ignore errors during sync
      } finally {
        _trailSyncInProgress.remove(activity.id);
      }
    }
  }

  Future<void> syncPendingCompletedActivities(List<Activity> activities) async {
    final remote = _remoteOrNull();
    if (remote == null) return;

    for (final activity in activities) {
      if (activity.status != ActivityStatus.completed ||
          !activity.pendingSync) {
        continue;
      }

      final savedRemotely = await _trySaveRemote(activity, remote);

      if (!savedRemotely) {
        continue;
      }

      activity.pendingSync = false;
      await _localStore.deleteActivity(activity.id);
      await _plannedTrailStore.deleteTrail(activity.id);
    }
  }

  Future<String> addPlannedActivity(
    Activity activity,
    List<List<TrailPoint>> trailPoints,
  ) async {
    if (activity.status != ActivityStatus.planned) {
      throw ArgumentError('Activity must have status planned');
    }

    final hasGeometry = trailPoints.any((segment) => segment.isNotEmpty);

    if (!hasGeometry) {
      throw ArgumentError('Trail geometry is required');
    }

    if (activity.id.isEmpty) {
      activity.id = _localStore.createId();
    }

    final plannedTrail = PlannedTrail(
      activityId: activity.id,
      trailId: activity.trailId,
      segments: trailPoints,
    );

    try {
      await _localStore.upsertActivity(activity);
      await _plannedTrailStore.saveTrail(plannedTrail);
    } catch (_) {
      await _localStore.deleteActivity(activity.id);
      await _plannedTrailStore.deleteTrail(activity.id);
      rethrow;
    }

    await _trySaveRemote(activity, _remoteOrNull());
    return activity.id;
  }

  Future<String?> addActivity(Activity activity) async {
    if (activity.id.isEmpty) {
      activity.id = _localStore.createId();
    }
    await _saveActivity(activity);

    return activity.id;
  }

  Future<void> updateActivity(Activity activity) async {
    if (activity.id.isEmpty) {
      activity.id = _localStore.createId();
    }
    await _saveActivity(activity);
  }

  Future<void> deleteActivity(String id) async {
    final remote = _remoteOrNull();
    if (remote != null) {
      await remote.deleteActivity(id);
    }

    await _localStore.deleteActivity(id);
    await _plannedTrailStore.deleteTrail(id);
  }

  Future<void> clearLocalData() async {
    await _localStore.clear();
    await _plannedTrailStore.clear();
    _trailSyncInProgress.clear();
  }

  Future<void> _saveActivity(Activity activity) async {
    final remote = _remoteOrNull();

    if (activity.status != ActivityStatus.completed) {
      activity.pendingSync = false;
      await _localStore.upsertActivity(activity);
      await _trySaveRemote(activity, remote);
      return;
    }

    activity.pendingSync = true;
    await _localStore.upsertActivity(activity);
    return;
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
    Stream<User?> authStream,
    Stream<List<Activity>> remoteStream,
  ) {
    late StreamSubscription<List<Activity>> localSubscription;
    late StreamSubscription<List<Activity>> remoteSubscription;
    late StreamSubscription<User?> authSubscription;

    List<Activity> localActivities = const [];
    List<Activity> remoteActivities = const [];
    User? currentUser;

    final controller = StreamController<List<Activity>>();

    void emitMerged() {
      if (controller.isClosed) return;
      controller.add(_mergeActivities(localActivities, remoteActivities));
    }

    controller.onListen = () {
      localSubscription = localStream.listen((activities) {
        localActivities = activities;
        if (currentUser != null) {
          final remote = databaseServiceFactory != null
              ? databaseServiceFactory!()
              : DatabaseService();
          _syncPendingActivities(activities, remote);
        }
        emitMerged();
      }, onError: controller.addError);

      authSubscription = authStream.listen((user) {
        currentUser = user;
        if (user == null) {
          remoteActivities = const [];
          emitMerged();
        }
      });

      remoteSubscription = remoteStream.listen((activities) {
        remoteActivities = activities;
        emitMerged();
      }, onError: controller.addError);
    };

    controller.onCancel = () async {
      await localSubscription.cancel();
      await remoteSubscription.cancel();
      await authSubscription.cancel();
    };

    return controller.stream;
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

  void _syncPendingActivities(
    List<Activity> activities,
    DatabaseService remote,
  ) {
    for (final activity in activities) {
      if (activity.status == ActivityStatus.completed) {
        unawaited(_trySaveRemote(activity, remote));
      }
    }
  }

  Future<Activity?> fetchActivityDetails(String id) async {
    final remote = _remoteOrNull();
    final localActivity = await _findLocalActivity(id);

    if (remote != null) {
      try {
        final docData = await remote.fetchActivity(id);

        if (docData != null) {
          final remoteActivity = Activity.fromJson(id, docData);

          if (remoteActivity.status == ActivityStatus.planned) {
            await _localStore.upsertActivity(remoteActivity);
          } else {
            await _localStore.deleteActivity(id);
            await _plannedTrailStore.deleteTrail(id);
          }

          return remoteActivity;
        }
      } catch (_) {
        // fallback: read from hive
      }
    }

    if (localActivity == null) return null;
    return localActivity;
  }

  Future<Activity?> _findLocalActivity(String id) async {
    final localActivities = await _localStore.streamActivities().first;
    try {
      return localActivities.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveNote(Activity activity, ActivityNote note) async {
    List<ActivityNote> updatedNotes = List.from(activity.notes);
    final index = updatedNotes.indexWhere((n) => n.id == note.id);
    final isNewNote = index == -1;

    ActivityNote? oldNote = isNewNote ? null : updatedNotes[index];

    if (isNewNote) {
      updatedNotes.add(note);
    } else {
      updatedNotes[index] = note;
    }

    activity.notes = updatedNotes;
    if (activity.status == ActivityStatus.planned) {
      await _localStore.upsertActivity(activity);
    }

    final remote = _remoteOrNull();
    if (remote == null) return;

    final noteToSaveRemotely = ActivityNote(
      id: note.id,
      text: note.text,
      imageUrls: note.imageUrls,
      createdAt: note.createdAt,
    );

    try {
      if (isNewNote) {
        await remote.addNoteToArray(activity.id, noteToSaveRemotely.toJson());
      } else if (oldNote != null) {
        await remote.removeNoteFromArray(activity.id, oldNote.toJson());
        await remote.addNoteToArray(activity.id, noteToSaveRemotely.toJson());
      }
    } catch (e) {
      //note save in local cache
    }
  }

  Future<void> deleteNote(Activity activity, ActivityNote noteToDelete) async {
    List<ActivityNote> updatedNotes = List.from(activity.notes)
      ..removeWhere((n) => n.id == noteToDelete.id);

    activity.notes = updatedNotes;
    if (activity.status == ActivityStatus.planned) {
      await _localStore.upsertActivity(activity);
    }

    final remote = _remoteOrNull();
    if (remote != null) {
      try {
        remote.removeNoteFromArray(activity.id, noteToDelete.toJson());
      } catch (_) {}
    }
  }
}
