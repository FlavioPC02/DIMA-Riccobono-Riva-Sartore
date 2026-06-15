import 'dart:async';

import 'package:application/services/background_tracking_service.dart';
import 'package:application/services/phone_wear_sync.dart';
import 'package:flutter/cupertino.dart';
import 'package:hike_core/hike_core.dart';

import '../models/location_point.dart';
import 'package:application/core/repository/location_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

part '../models/location_state.dart';

//Signature for the callback that save activity on DB and cubit
typedef OnActivitySaved = Future<void> Function({
  required double distance,
  required double elevationGap,
  required Duration elapsed,
});

//Callback for screen navigation after stop
typedef OnNavigateAfterStop = void Function();

class LocationCubit extends Cubit<LocationState> {
  LocationCubit(
    this._repository, {
    BackgroundTrackingService? backgroundTrackingService,
    PhoneWearSyncService? wearSyncService,
    OnActivitySaved? onActivitySaved,
    OnNavigateAfterStop? onNavigateAfterStop,
    Duration? initialEta,
  }) : _backgroundTrackingService =
           backgroundTrackingService ?? DefaultBackgroundTrackingService(),
       _wearSync = wearSyncService ?? PhoneWearSyncService(),
       _onActivitySaved = onActivitySaved,
       _onNavigateAfterStop = onNavigateAfterStop,
       _remainingEta = initialEta ?? Duration.zero,
       super(const LocationState.idle()) {
         _wearSync.initialize();
         _wearSync.onPauseFromWatch = pauseTracking;
         _wearSync.onResumeFromWatch = resumeTracking;
         
         //Disable screen navigation because stop triggered from watch. The phone may be in their pockets.
         _wearSync.onStopFromWatch = () => stopAndSave(navigate: false);
       }

  final ILocationRepository _repository;
  final BackgroundTrackingService _backgroundTrackingService;
  final PhoneWearSyncService _wearSync;

  OnActivitySaved? _onActivitySaved;
  OnNavigateAfterStop? _onNavigateAfterStop;

  StreamSubscription<LocationPoint>? _locationSub;

  final _stopWatch = Stopwatch();
  Duration get elapsed => _stopWatch.elapsed;
  bool get isRunning => _stopWatch.isRunning;

  static const double _movementSpeedThresholdMps = 0.4;
  static const Duration _movementSampleMaxAge = Duration(seconds: 12);

  Duration _remainingEta;
  DateTime? _lastEtaUpdateAt;

  double _totalDistance = 0;

  DateTime get eta => DateTime.now().add(_remainingEta);

  void setInitialEta(Duration duration) {
    _remainingEta = duration;
    _lastEtaUpdateAt = DateTime.now();
  }

  void setTotalDistance(double distance) {
    _totalDistance = distance;
  }

  void registerStopCallbacks({
    required OnActivitySaved onActivitySaved,
    required OnNavigateAfterStop onNavigateAfterStop,
  }) {
    _onActivitySaved = onActivitySaved;
    _onNavigateAfterStop = onNavigateAfterStop;
  }

  void unregisterStopCallbacks() {
    _onActivitySaved = null;
    _onNavigateAfterStop = null;
  }

  Future<void> startTracking() async {
    if (state.isActive) return;

    _stopWatch.reset();
    _stopWatch.start();
    _lastEtaUpdateAt = DateTime.now();

    //Rehydrate persisted points and recompute metrics so the displayed totals survive an app restart
    final saved = _repository.getAll();
    final (dist, gap, asc, desc) = _computeMetrics(saved);

    emit(
      LocationState.tracking(
        points: saved,
        current: saved.isEmpty ? null : saved.last,
        distance: dist,
        elevationGap: gap,
        totalAscent: asc,
        totalDescent: desc,
        eta: eta,
      ),
    );

    //listen for points coming from the background isolate
    _locationSub = _backgroundTrackingService.watchLocation().listen(
      (point) async {
        debugPrint('[LocationCubit] GPS point received: '
            'lat=${point.lat} lng=${point.lng} alt=${point.altitude}');
        if (isClosed) return;

        if (state.isPaused) {
          emit(
            LocationState.paused(
              points: state.points,
              current: point,
              distance: state.distance,
              elevationGap: state.elevationGap,
              totalAscent: state.totalAscent,
              totalDescent: state.totalDescent,
              eta: eta,
            ),
          );
          return;
        }

        final newPoints = [...state.points, point];

        //Distance: add the leg from previous fix to the new one
        double addedDistance = 0;
        if (state.points.isNotEmpty) {
          addedDistance = _haversine(state.points.last, point);
        }
        final newDistance = state.distance + addedDistance;

        //Elevation
        double? newGap = state.elevationGap;
        double newAscent = state.totalAscent;
        double newDescent = state.totalDescent;

        final firstAlt = newPoints.first.altitude;
        newGap = point.altitude - firstAlt;

        if (state.points.isNotEmpty) {
          final prev = state.points.last;
          final delta = point.altitude - prev.altitude;
          if (delta > 0) {
            newAscent += delta;
          } else {
            newDescent += delta.abs();
          }
        }

        final newEta = _computeEta(newPoints);

        emit(
          LocationState.tracking(
            points: newPoints,
            current: point,
            distance: newDistance,
            elevationGap: newGap,
            totalAscent: newAscent,
            totalDescent: newDescent,
            eta: newEta,
          ),
        );

        _wearSync.sendStats(
          HikeLiveStats(
            elapsedTime: elapsed, 
            distanceMeters: newDistance,
            totalDistanceMeters: _totalDistance,
            elevationGapMeters: newGap, 
            eta: eta,
          ),
        );

        unawaited(_repository.save(point));
      },
      onError: (e) {
        debugPrint('[LocationCubit] GPS stream error: $e');
        if (!isClosed) emit(LocationState.error(e.toString()));
      },
    );

    await _backgroundTrackingService.startTracking();
    debugPrint('[LocationCubit] startTracking() completed, isTracking=${state.isTracking}');
    _wearSync.sendStatus(HikeRecordingStatus.recording);
  }

  Future<void> pauseTracking() async {
    if (!state.isTracking) return;
    _stopWatch.stop();
    _wearSync.sendStatus(HikeRecordingStatus.paused);
    
    emit(
      LocationState.paused(
        points: state.points,
        current: state.current,
        distance: state.distance,
        elevationGap: state.elevationGap,
        totalAscent: state.totalAscent,
        totalDescent: state.totalDescent,
        eta: state.eta,
      ),
    );
  }

  Future<void> resumeTracking() async {
    if (!state.isPaused) return;
    _stopWatch.start();
    _lastEtaUpdateAt = DateTime.now();
    _wearSync.sendStatus(HikeRecordingStatus.recording);

    emit(
      LocationState.tracking(
        points: state.points,
        current: state.current,
        distance: state.distance,
        elevationGap: state.elevationGap,
        totalAscent: state.totalAscent,
        totalDescent: state.totalDescent,
        eta: state.eta,
      ),
    );
  }

  Future<void> stopAndSave({bool navigate = true}) async {
    _stopWatch.stop();
    final elapsed = _stopWatch.elapsed;

    await _locationSub?.cancel();
    _locationSub = null;
    await _backgroundTrackingService.stopTracking();

    _wearSync.sendStatus(HikeRecordingStatus.stopped);

    await _onActivitySaved?.call(
      distance: state.distance,
      elevationGap: state.elevationGap ?? 0.0,
      elapsed: elapsed,
    );

    if (!isClosed) emit(const LocationState.idle());
    await clearHistory();

    if (navigate) {
      _onNavigateAfterStop?.call();
    }
  }

  Future<void> clearHistory() async {
    await _repository.clear();
    if (!isClosed) {
      emit(LocationState.tracking(points: const [], current: state.current));
    }
  }

  @override
  Future<void> close() async {
    await _locationSub?.cancel();
    _locationSub = null;
    await _backgroundTrackingService.stopTracking();
    return super.close();
  }

  //Helpers

  DateTime _computeEta(List<LocationPoint> points) {
    final now = DateTime.now();

    if(!_isUserMoving(points)) {
      _lastEtaUpdateAt = now;
      return now.add(_remainingEta);
    }

    final lastUpdateAt = _lastEtaUpdateAt ?? now;
    _lastEtaUpdateAt = now;

    final elapsed = now.difference(lastUpdateAt);
    final next = _remainingEta - elapsed;
    _remainingEta = next.isNegative ? Duration.zero : next;

    return now.add(_remainingEta);
  }

  bool _isUserMoving(List<LocationPoint> points) {
    if (points.length < 2) return false;

    final latest = points.last;
    final previous = points[points.length - 2];

    final sampleAge = DateTime.now().difference(latest.timestamp);
    if (sampleAge > _movementSampleMaxAge) return false;

    final elapsedSeconds = latest.timestamp
      .difference(previous.timestamp)
      .inSeconds;
    if (elapsedSeconds <= 0) return false;

    final traveledMeters = _haversine(previous, latest);

    return traveledMeters / elapsedSeconds >= _movementSpeedThresholdMps;
  }

  (double dist, double? gap, double asc, double desc) _computeMetrics(
    List<LocationPoint> pts,
  ) {
    if (pts.isEmpty) return (0, null, 0, 0);

    double dist = 0;
    double asc = 0;
    double desc = 0;
    double? gap;

    final firstAlt = pts.first.altitude;

    for (var i = 1; i < pts.length; i++) {
      dist += _haversine(pts[i - 1], pts[i]);

      final prevAlt = pts[i - 1].altitude;
      final currAlt = pts[i].altitude;

      final delta = currAlt - prevAlt;
      if (delta > 0) {
        asc += delta;
      } else {
        desc += delta.abs();
      }
    }

    gap = pts.last.altitude - firstAlt;

    return (dist, gap, asc, desc);
  }

  double _haversine(LocationPoint a, LocationPoint b) {
    LatLng first = LatLng(a.lat, a.lng);
    LatLng second = LatLng(b.lat, b.lng);

    return Haversine().distance(first, second);
  }
}
