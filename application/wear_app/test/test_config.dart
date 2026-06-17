import 'package:flutter_test/flutter_test.dart';
import 'package:hike_core/hike_core.dart';
import 'package:wear_app/features/models/watch_location_state.dart';

import 'mocks/mocks_manual.dart';

void setupTest() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerAllFallbacks();
}

WatchLocationState buildState({
  HikeRecordingStatus status = HikeRecordingStatus.recording,
  double distanceMeters = 0,
  double totalDistanceMeters = 0,
  double elevationGapMeters = 0,
  Duration elapsedTime = Duration.zero,
}) {
  return WatchLocationState(
    status: status,
    isConnecting: false,
    stats: HikeLiveStats(
      elapsedTime: elapsedTime,
      distanceMeters: distanceMeters,
      totalDistanceMeters: totalDistanceMeters,
      elevationGapMeters: elevationGapMeters,
      eta: DateTime(2025),
    ),
  );
}