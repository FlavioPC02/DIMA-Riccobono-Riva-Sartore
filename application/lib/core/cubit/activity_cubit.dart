import 'dart:async';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/activity_note.dart';
import 'package:application/core/repository/activity_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:application/core/models/planned_trail.dart';

class ActivityCubit extends Cubit<List<Activity>> {
  final ActivityRepository _repository;
  StreamSubscription<List<Activity>>? _subscription;
  StreamSubscription<User?>? _authSubscription;

  ActivityCubit(this._repository) : super([]) {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _onLoggedOut();
      } else {
        _onLoggedIn();
      }
    });
  }

  void _onLoggedOut() {
    _subscription?.cancel();
    _subscription = null;
    emit([]);
  }

  void _onLoggedIn() {
    _subscription?.cancel();
    _subscription = _repository.streamActivities().listen((activities) {
      emit(activities);

      unawaited(_repository.syncPlannedActivitiesForOffline(activities));
      unawaited(_repository.syncPendingCompletedActivities(activities));
    });
  }

  Future<void> addActivity(Activity activity) async {
    await _repository.addActivity(activity);
  }

  Future<void> addPlannedActivity(
    Activity activity,
    List<List<TrailPoint>> trailPoints,
  ) async {
    await _repository.addPlannedActivity(activity, trailPoints);
  }

  Future<PlannedTrail?> getPlannedTrail(String activityId) async {
    return await _repository.getPlannedTrail(activityId);
  }

  Stream<Set<String>> watchDownloadedTrailIds() {
    return _repository.watchDownloadedTrailIds();
  }

  Future<void> updateActivity(Activity activity) async {
    final previousState = state;

    emit(
      state
          .map((current) => current.id == activity.id ? activity : current)
          .toList(growable: false),
    );

    try {
      await _repository.updateActivity(activity);
    } catch (_) {
      emit(previousState);
      rethrow;
    }
  }

  Future<void> deleteActivity(String id) async {
    await _repository.deleteActivity(id);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _authSubscription?.cancel();
    _subscription = null;
    _authSubscription = null;
    return super.close();
  }

  Future<void> loadActivityDetails(String id) async {
    final fetchedActivity = await _repository.fetchActivityDetails(id);

    if (fetchedActivity != null) {
      final newState = state.map((a) {
        return a.id == id ? fetchedActivity : a;
      }).toList();

      emit(newState);
    }
  }

  Future<void> addOrUpdateNote(Activity activity, ActivityNote note) async {
    final noteId = note.id.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : note.id;
    final finalNote = ActivityNote(
      id: noteId,
      text: note.text,
      imageUrls: note.imageUrls,
      createdAt: note.createdAt,
    );

    List<ActivityNote> updatedNotes = List.from(activity.notes);
    final index = updatedNotes.indexWhere((n) => n.id == finalNote.id);

    if (index >= 0) {
      updatedNotes[index] = finalNote;
    } else {
      updatedNotes.add(finalNote);
    }

//    final updatedActivity = activity.copyWith(notes: updatedNotes);
//    final newState = state.map((a) {
//      return a.id == updatedActivity.id ? updatedActivity : a;
//    }).toList();
//
//    emit(newState);

    await _repository.saveNote(activity, finalNote);

    activity.notes = updatedNotes;
    emit(List<Activity>.from(state));
  }

  Future<void> deleteNote(Activity activity, String noteId) async {
    final noteToDelete = activity.notes.firstWhere((n) => n.id == noteId);

    await _repository.deleteNote(activity, noteToDelete);

    List<ActivityNote> updatedNotes = List.from(activity.notes)
      ..removeWhere((n) => n.id == noteId);

    activity.notes = updatedNotes;
    emit(List<Activity>.from(state));

//    final updatedActivity = activity.copyWith(notes: updatedNotes);
//    final newState = state.map((a) {
//      return a.id == updatedActivity.id ? updatedActivity : a;
//    }).toList();
//
//    emit(newState);
  }
}
