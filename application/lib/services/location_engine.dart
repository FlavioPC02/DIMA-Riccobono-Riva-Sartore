import 'dart:async';
import 'package:application/core/models/location_point.dart';
import 'package:application/core/repository/location_repository.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

enum TrackingMode {
  foreground,
  background,
}

class LocationEngine {
  final TrackingMode mode;

  StreamSubscription<Position>? _sub;
  bool _isStopped = false;

  final _controller = StreamController<LocationPoint>.broadcast();
  Stream<LocationPoint> get stream => _controller.stream;

  LocationEngine._(this.mode);

  factory LocationEngine.foreground() {
    return LocationEngine._(TrackingMode.foreground);
  }

  factory LocationEngine.background() {
    return LocationEngine._(TrackingMode.background);
  }

  Future<void> start() async {
    _isStopped = false;
    final settings = _buildSettings();

    _sub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_onPosition);
  }

  Future<void> _onPosition(Position position) async {
    if (_isStopped) return;
    debugPrint('nuovo candidato punto');
    if (position.accuracy >= 50 && position.altitudeAccuracy > 50.0) return;

    final point = LocationPoint(
      lat: position.latitude,
      lng: position.longitude,
      altitude: position.altitude,
      positionAccuracy: position.accuracy,
      altitudeAccuracy: position.altitudeAccuracy,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      if (_isStopped) return;
      await LocationRepository.saveCurrent(point);
      if (_isStopped) return;
      await LocationRepository.addToRoute(point);

      if (_isStopped || _controller.isClosed) return;
      _controller.add(point);
      debugPrint('punto salvato in background');
    } catch (e, st) {
      debugPrint('LocationEngine: errore salvataggio punto $e');
      debugPrintStack(stackTrace: st, label: 'LocationEngine');
    }
  }

  LocationSettings _buildSettings() {
    switch (mode) {
      case TrackingMode.foreground:
        return const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        );

      case TrackingMode.background:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        );
    }
  }

  Future<void> stop() async {
    _isStopped = true;
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> close() async {
    await stop();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}