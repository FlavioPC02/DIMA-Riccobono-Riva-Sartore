import 'dart:async';

import 'package:application/core/models/location_point.dart';
import 'package:application/core/repository/location_repository.dart';
import 'package:application/services/background_tracking_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

part '../models/location_state.dart';

class LocationCubit extends Cubit<LocationState> {
  LocationCubit(
    this._repository, {
    BackgroundTrackingService? backgroundTrackingService,
  }) : _backgroundTrackingService =
           backgroundTrackingService ?? DefaultBackgroundTrackingService(),
       super(const LocationState.idle());

  final ILocationRepository _repository;
  final BackgroundTrackingService _backgroundTrackingService;
  StreamSubscription<LocationPoint>? _locationSub;

  Future<void> startTracking() async {
    if (state.isTracking) return;

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
      ));

    //listen for points coming from the background isolate
    _locationSub = _backgroundTrackingService.watchLocation().listen(
      (point) async {
        if (isClosed) return;
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

        emit(
          LocationState.tracking(
            points: newPoints,
            current: point,
            distance: newDistance,
            elevationGap: newGap,
            totalAscent: newAscent,
            totalDescent: newDescent,
          ));

        unawaited(_repository.save(point));
      },
      onError: (e) {
        if (!isClosed) emit(LocationState.error(e.toString()));
      }
    );

    await _backgroundTrackingService.startTracking();
  }

  Future<void> stopTracking() async {
    await _locationSub?.cancel();
    _locationSub = null;
    await _backgroundTrackingService.stopTracking();
    if (!isClosed) emit(const LocationState.idle());
  }

  Future<void> clearHistory() async {
    await _repository.clear();
    if (!isClosed) {
      emit(LocationState.tracking(points: const [], current: state.current));
    }
  }

  @override
  Future<void> close() async {
    await stopTracking();
    return super.close();
  }

  //Helpers
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
    //    const double r = 6371000; // Earth radius in meters
    //    double dLat = _degToRad(position.latitude - lkp.latitude);
    //    double dLng = _degToRad(position.longitude - lkp.longitude);
    //
    //    double a = math.sin(dLat / 2.0) * math.sin(dLat / 2.0) +
    //      math.cos(_degToRad(lkp.latitude)) * math.cos(_degToRad(position.latitude)) *
    //      math.sin(dLng / 2.0) * math.sin(dLng / 2.0);
    //
    //    double c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
    //    double distance = r * c;
    //
    //    if(distance < 5.0) {
    //      return 0.0;
    //    } else {
    //      return distance;
    //    }

    LatLng first = LatLng(a.lat, a.lng);
    LatLng second = LatLng(b.lat, b.lng);

    return Haversine().distance(first, second);
  }
}
