import 'dart:async';

import 'package:hike_core/hike_core.dart';
import 'package:wear_app/features/models/watch_location_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wear_app/features/services/watch_wear_sync.dart';

class WatchLocationCubit extends Cubit<WatchLocationState> {
  final WatchWearSyncService _sync;

  late final StreamSubscription<HikeLiveStats> _statsSubscription;
  late final StreamSubscription<HikeRecordingStatus> _statusSubscription;

  //emits a single event when the phone opens the navigator
  final _navigationController = StreamController<void>.broadcast();

  Stream<void> get onNavigateToHike => _navigationController.stream;

  WatchLocationCubit(this._sync) : super(WatchLocationState.initial()) {
    _sync.initalize();

    _checkInitialNavigation();

    _sync.onOpenNavigation = () {
      if(!_navigationController.isClosed) {
        _navigationController.add(null);
      }
    };

    _statsSubscription = _sync.statsStream.listen((stats) {
      emit(state.copyWith(
        stats: stats,
        isConnecting: false,
        lastUpdate: DateTime.now(),
      ));
    });

    _statusSubscription = _sync.statusStream.listen((status) {
      emit(state.copyWith(
          status: status,
          stats: status == HikeRecordingStatus.stopped ? HikeLiveStats.empty() : null,
          lastUpdate: DateTime.now(),
      ));
    });
  }

  Future<void> _checkInitialNavigation() async {
    final should = await _sync.shouldOpenNavigation();
    if (should && !_navigationController.isClosed) {
      _navigationController.add(null);
    }
  }

  Future<void> pause() async {
    emit(state.copyWith(
      status: HikeRecordingStatus.paused,
      lastUpdate: DateTime.now(),
    ));
    await _sync.sendPause();
  }

  Future<void> resume() async {
    emit(state.copyWith(
      status: HikeRecordingStatus.recording,
      lastUpdate: DateTime.now(),
    ));
    await _sync.sendResume();
  }

  Future<void> stop() async {
    emit(state.copyWith(
      stats: HikeLiveStats.empty(),
      status: HikeRecordingStatus.stopped,
      lastUpdate: DateTime.now(),
    ));
    await _sync.sendStop();
  }

  @override
  Future<void> close() async {
    await _statsSubscription.cancel();
    await _statusSubscription.cancel();
    await _navigationController.close();
    _sync.dispose();
    super.close();
  }
}