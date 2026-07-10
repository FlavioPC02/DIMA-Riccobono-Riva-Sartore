import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

bool _isNoSensorError(Object? error) {
  if (error is PlatformException) {
    return error.code == 'NO_SENSOR';
  }

  final message = error.toString();
  return message.contains('rotation_sensor/orientation') &&
      message.contains('NO_SENSOR');
}

bool _flutterErrorHandlerInstalled = false;

void _ignoreExpectedNoSensorFlutterError() {
  if (_flutterErrorHandlerInstalled) {
    return;
  }

  _flutterErrorHandlerInstalled = true;
  final previousOnError = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isNoSensorError(details.exception)) {
      debugPrint('Rotation sensor unavailable; location heading disabled.');
      return;
    }

    if (previousOnError != null) {
      previousOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
}

Stream<LocationMarkerHeading?> safeRotationSensorHeadingStream() {
  _ignoreExpectedNoSensorFlutterError();

  return const LocationMarkerDataStreamFactory()
      .fromRotationSensorHeadingStream()
      .handleError((Object error, StackTrace stackTrace) {
        debugPrint('Rotation sensor unavailable; location heading disabled.');
      }, test: _isNoSensorError);
}
