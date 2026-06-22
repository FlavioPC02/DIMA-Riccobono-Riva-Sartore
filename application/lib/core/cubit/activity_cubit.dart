import 'dart:async';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/activity_note.dart';
import 'package:application/core/repository/activity_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ActivityCubit extends Cubit<List<Activity>> {
  final ActivityRepository _repository;
  StreamSubscription<List<Activity>>? _subscription;

  ActivityCubit(this._repository) : super([]) {
    _subscription = _repository.streamActivities().listen((activities) {
      emit(activities);
    });
  }

  Future<void> addActivity(Activity activity) async {
    await _repository.addActivity(activity);
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
    final noteId = note.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : note.id;
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

    final updatedActivity = activity.copyWith(notes: updatedNotes);
    final newState = state.map((a) {
      return a.id == updatedActivity.id ? updatedActivity : a;
    }).toList();

    emit(newState); 

    await _repository.saveNote(activity, finalNote);
  }

  Future<void> deleteNote(Activity activity, String noteId) async {
    final noteToDelete = activity.notes.firstWhere((n) => n.id == noteId);

    await _repository.deleteNote(activity, noteToDelete);

    List<ActivityNote> updatedNotes = List.from(activity.notes)
      ..removeWhere((n) => n.id == noteId);

    final updatedActivity = activity.copyWith(notes: updatedNotes);
    final newState = state.map((a) {
      return a.id == updatedActivity.id ? updatedActivity : a;
    }).toList();
    
    emit(newState);
  }
}
