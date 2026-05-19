import 'package:application/core/cubit/location_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class LifecycleManager extends WidgetsBindingObserver {

  final LocationCubit cubit;

  LifecycleManager(this.cubit);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final service = FlutterBackgroundService();

    switch (state) {
      case AppLifecycleState.paused:
        // App reduced/backgrounded => keep tracking via foreground service.
        await cubit.stopTracking();
        await service.startService();
        break;

      case AppLifecycleState.resumed:
        // App back to foreground => stop background service and restart foreground stream.
        service.invoke('stopService');
        await cubit.startForegroundTracking();
        break;

      case AppLifecycleState.detached:
        // App closed/terminated => stop everything.
        await cubit.stopTracking();
        service.invoke('stopService');
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }
}