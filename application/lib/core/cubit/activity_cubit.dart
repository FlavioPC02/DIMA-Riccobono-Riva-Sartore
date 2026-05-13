import 'dart:async';
import 'package:application/core/models/activity.dart';
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
    await _repository.updateActivity(activity);
  }

  Future<void> deleteActivity(String id) async {
    await _repository.deleteActivity(id);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
