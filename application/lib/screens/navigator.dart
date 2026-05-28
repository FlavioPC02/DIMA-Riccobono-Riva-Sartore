import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/screens/homepage.dart';
import 'package:application/services/notification_service.dart';
import 'package:application/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart' as geo;
import '../core/theme/app_colors.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NavigatorScreen extends StatefulWidget {
  //ottengo un Map<String, dynamic> id, name, coordinates
  final Map<String, dynamic> trail;
  final Activity activity;

  const NavigatorScreen({
    super.key,
    required this.trail,
    required this.activity,
  });

  @override
  State<NavigatorScreen> createState() {
    return _NavigatorScreenState();
  }
}

class _NavigatorScreenState extends State<NavigatorScreen> {
  static const double _offsetBound = 32;
  static const double _offsetBoundTop = 37;
  static const double _offTrailThresholdMeters = 50.0;
  static const double R = 6371000; // Earth radius in meters
  static const double _movementSpeedThresholdMps = 0.4;
  static const Duration _movementSampleMaxAge = Duration(seconds: 12);

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  final MapController _mapController = MapController();

  late Stopwatch _stopwatch;
  late Timer _timer;
  Duration _elapsedTime = Duration.zero;
  DateTime _lastOffTrailNotificationTime = DateTime.fromMillisecondsSinceEpoch(
    0,
  );
  Duration _remainingEta = Duration.zero;
  DateTime? _lastEtaUpdateAt;
  late final LocationCubit _locationCubit;

  bool _isLocatingUser = false;

  //CONFIGURABLE VARIABLES

  //TODO: define final app name
  //app name used in API requests (user agent)
  final String _appName = 'FlutterHikingApp/1.0';

  //fallback location coordinates (Rome, Italy)
  LatLng _currentCenter = const LatLng(41.8967, 12.4822);

  //default zoom level for the map
  double mapZoom = 12.0;

  @override
  void initState() {
    super.initState();

    _locationCubit = sl<LocationCubit>();

    _stopwatch = Stopwatch();
    _stopwatch.start();

    _remainingEta = Duration(minutes: widget.activity.durationMinutes);
    _lastEtaUpdateAt = DateTime.now();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_stopwatch.isRunning) return;
      setState(() {
        _elapsedTime = _stopwatch.elapsed;
      });
    });

    _buildMap();
    _locationCubit.startTracking();
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    _locationCubit.stopTracking();
    _locationCubit.close();
    super.dispose();
  }

  void _toggleStopwatch() {
    final shouldStartTracking = !_stopwatch.isRunning;

    setState(() {
      if (shouldStartTracking) {
        _stopwatch.start();
      } else {
        _stopwatch.stop();
      }
      _elapsedTime = _stopwatch.elapsed;
    });

    if (shouldStartTracking) {
      unawaited(_locationCubit.startTracking());
    } else {
      unawaited(_locationCubit.stopTracking());
    }
  }

  Future<void> _stopRecording() async {
    setState(() {
      _stopwatch.stop();
      _elapsedTime = _stopwatch.elapsed;
    });

    final cubit = _locationCubit;
    final activityCubit = context.read<ActivityCubit>();
    final profileCubit = context.read<ProfileCubit>();

    final activity = widget.activity;
    activity.trackedDistance = cubit.state.distance;
    activity.trackedElevationGap = cubit.state.elevationGap ?? 0.0;
    activity.trackedTime = _elapsedTime;
    activity.status = ActivityStatus.completed;

    await cubit.stopTracking();

    if (!mounted) {
      return;
    }

    if (activity.id.isEmpty) {
      await activityCubit.addActivity(activity);
    } else {
      await activityCubit.updateActivity(activity);
    }
    
    //update profile stats
    final profile = profileCubit.state;
    profileCubit.updateXp(profile.xp + activity.xpEarned);
    cubit.clearHistory();

    if (!mounted) {
      return;
    }

    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(builder: (_) => const Navigation()),
    );
  }

  void _showPathDistanceNotification(int distance, {String? direction}) {
    final notificationsEnabled = context
        .read<SettingsCubit>()
        .state
        .notifications;

    if (!notificationsEnabled) return;

    final String dirText = direction ?? '';
    final String body = 'You are $distance m from the trail. \n$dirText.';

    NotificationService.showNotification(title: 'Out of trail', body: body);
  }

  Future<void> _buildMap() async {
    await _centerMapOnTrail();
    _buildPolylines();
    await _fitTrailInViewport();
  }

  //when the widget is first built, check if location services are enabled and permissions are granted, then fetch the current location
  Future<void> _centerMapOnTrail() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!mounted) return;

    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (!mounted) return;

    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      _showLocationPermissionDialog();
      return;
    }

    //set map center to the geometric center of the trail
    LatLng trailCenter = _getPolylineCenter();
    setState(() {
      _currentCenter = trailCenter;
    });
  }

  //get the geometric center of the trail
  LatLng _getPolylineCenter() {
    LatLng first = widget.trail['subTrails'].first.first;
    LatLng last = widget.trail['subTrails'].last.last;

    double lat = (first.latitude + last.latitude) / 2.0;
    double lng = (first.longitude + last.longitude) / 2.0;

    return LatLng(lat, lng);
  }

  //returns the trail extremes points
  LatLngBounds _buildTrailBounds(List<List<LatLng>> coordinates) {
    if (coordinates.isEmpty) {
      throw ArgumentError('coordinates cannot be empty');
    }

    final coordinateList = coordinates.expand((e) => [e[1]]).toList();
    final first = coordinateList.first;

    final bounds = coordinateList.skip(1).fold(
      (
        minLat: first.latitude,
        maxLat: first.latitude,
        minLng: first.longitude,
        maxLng: first.longitude,
      ),
      (acc, p) {
        final lat = p.latitude;
        final lng = p.longitude;
        return (
          minLat: lat < acc.minLat ? lat : acc.minLat,
          maxLat: lat > acc.maxLat ? lat : acc.maxLat,
          minLng: lng < acc.minLng ? lng : acc.minLng,
          maxLng: lng > acc.maxLng ? lng : acc.maxLng,
        );
      },
    );

    return LatLngBounds(
      LatLng(bounds.minLat, bounds.minLng),
      LatLng(bounds.maxLat, bounds.maxLng),
    );
  }

  //function which adjust mapZoom to fit the entire trail in the viewport
  Future<void> _fitTrailInViewport() async {
    if (!mounted) return;

    final coordinates = widget.trail['subTrails'];
    if (coordinates.isEmpty) return;

    final bounds = _buildTrailBounds(coordinates);
    final collapsedCardHeight = StatsRecordingCard.collapsedSheetHeight(
      context,
      widget.trail['name']?.toString() ?? 'Trail',
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.fromLTRB(
          _offsetBound,
          MediaQuery.of(context).padding.top + _offsetBoundTop,
          _offsetBound,
          MediaQuery.of(context).padding.bottom +
              collapsedCardHeight +
              _offsetBound,
        ),
      ),
    );
  }

  //function to move the camera to a specific location with a given zoom level
  void _moveCameraTo(double lat, double lng, double zoom) {
    _currentCenter = LatLng(lat, lng);
    _mapController.move(_currentCenter, zoom);
  }

  // dialog shown when location services are disabled
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Location service required',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Enable GPS to obtain the current location.',
            textAlign: TextAlign.center,
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    //open device settings to allow the user to enable location services
                    geo.Geolocator.openLocationSettings();
                  },
                  child: const Text('Enable location permission'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorBackground,
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Ignore',
                    style: TextStyle(color: AppColors.errorText),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // dialog shown when location permissions are denied
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Location permission required',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Without enabling the permission, it is not possible to obtain the current location.',
            textAlign: TextAlign.center,
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    //request location permissions
                    await geo.Geolocator.requestPermission();
                  },
                  child: const Text('Enable location permission'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorBackground,
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Ignore',
                    style: TextStyle(color: AppColors.errorText),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  //when the location button is pressed, check permissions and fetch the current location, then center the map on it
  Future<void> _centerMapOnUser() async {
    setState(() {
      _isLocatingUser = true;
    });

    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();

    if (!serviceEnabled) {
      if (mounted) setState(() => _isLocatingUser = false);
      _showLocationServiceDialog();
      return;
    }

    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLocatingUser = false);
      _showLocationPermissionDialog();
      return;
    }

    geo.Position position = await geo.Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _isLocatingUser = false;
      });
      _moveCameraTo(position.latitude, position.longitude, mapZoom);
    }
  }

  //function to build polyline layers declaratively
  List<Polyline> _buildPolylines() {
    List<Polyline> allLines = [];

    for (List<LatLng> subTrailsCoordinates in widget.trail['subTrails']) {
      allLines.add(
        Polyline(
          points: subTrailsCoordinates,
          strokeWidth: 6.0,
          color: AppColors.selectedTrail,
        ),
      );
    }

    //render selected line on top
    allLines.sort((a, b) => a.strokeWidth.compareTo(b.strokeWidth));
    return allLines;
  }

  // returns both distance (meters) and side sign for P relative to segment V->W
  // side > 0 => P is to the left of segment, side < 0 => to the right
  Map<String, double> _distanceAndSideToSegment(LatLng p, LatLng v, LatLng w) {
    final double latRef = _degToRad((v.latitude + w.latitude) / 2.0);
    double xFor(LatLng a) => _degToRad(a.longitude) * R * math.cos(latRef);
    double yFor(LatLng a) => _degToRad(a.latitude) * R;

    final double px = xFor(p);
    final double py = yFor(p);
    final double vx = xFor(v);
    final double vy = yFor(v);
    final double wx = xFor(w);
    final double wy = yFor(w);

    final double dx = wx - vx;
    final double dy = wy - vy;

    if (dx == 0 && dy == 0) {
      final double dist = ((px - vx) * (px - vx) + (py - vy) * (py - vy));
      return {'distance': math.sqrt(dist), 'side': 0.0};
    }

    final double t = ((px - vx) * dx + (py - vy) * dy) / (dx * dx + dy * dy);
    final double tt = t < 0 ? 0 : (t > 1 ? 1 : t);
    final double projx = vx + tt * dx;
    final double projy = vy + tt * dy;
    final double dist2 =
        (px - projx) * (px - projx) + (py - projy) * (py - projy);
    // cross product of segment (dx,dy) and vector from proj->P => sign indicates side
    final double cross = dx * (py - projy) - dy * (px - projx);
    return {'distance': math.sqrt(dist2), 'side': cross};
  }

  void checkUserOnTrail(LatLng position) {
    final List<List<LatLng>> subTrails =
        widget.trail['subTrails'] as List<List<LatLng>>;
    if (subTrails.isEmpty) return;

    double minDistance = double.infinity;
    double sideForMin = 0.0;

    for (final segment in subTrails) {
      if (segment.length < 2) continue;
      for (int i = 0; i < segment.length - 1; i++) {
        final LatLng a = segment[i];
        final LatLng b = segment[i + 1];
        final result = _distanceAndSideToSegment(position, a, b);
        final double d = result['distance']!;
        final double side = result['side']!;
        if (d < minDistance) {
          minDistance = d;
          sideForMin = side;
        }
      }
    }

    final int distanceMeters = minDistance.isFinite ? minDistance.round() : 0;
    final DateTime now = DateTime.now();

    if (distanceMeters > _offTrailThresholdMeters &&
        now.difference(_lastOffTrailNotificationTime).inSeconds >= 60) {
      _lastOffTrailNotificationTime = now;

      String direction;
      if (sideForMin > 0.0) {
        // P is left of segment -> suggest moving right
        direction = 'Move to the right to get back on the trail';
      } else if (sideForMin < 0.0) {
        direction = 'Move to the left to get back on the trail';
      } else {
        direction = 'Get closer to the trail';
      }

      _showPathDistanceNotification(distanceMeters, direction: direction);
    }
  }

  Duration _calculateEta(LocationState stats) {
    final now = DateTime.now();

    if (!_isUserMoving(stats)) {
      _lastEtaUpdateAt = now;
      return _remainingEta;
    }

    final lastUpdateAt = _lastEtaUpdateAt ?? now;
    _lastEtaUpdateAt = now;

    final nextRemaining = _remainingEta - now.difference(lastUpdateAt);
    _remainingEta = nextRemaining.isNegative ? Duration.zero : nextRemaining;

    return _remainingEta;
  }

  bool _isUserMoving(LocationState stats) {
    if (stats.points.length < 2) {
      return false;
    }

    final latestPoint = stats.points.last;
    final previousPoint = stats.points[stats.points.length - 2];
    final sampleAge = DateTime.now().difference(latestPoint.timestamp);
    if (sampleAge > _movementSampleMaxAge) {
      return false;
    }

    final elapsedSeconds = latestPoint.timestamp
        .difference(previousPoint.timestamp)
        .inSeconds;
    if (elapsedSeconds <= 0) {
      return false;
    }

    final traveledMeters = Haversine().distance(
      LatLng(previousPoint.lat, previousPoint.lng),
      LatLng(latestPoint.lat, latestPoint.lng),
    );

    return traveledMeters / elapsedSeconds >= _movementSpeedThresholdMps;
  }

  @override
  Widget build(BuildContext context) {
    final String trailName = widget.trail['name']?.toString() ?? 'Trail';

    return BlocProvider.value(
      value: _locationCubit,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _locationCubit.stopTracking();
        },
        child: BlocBuilder<LocationCubit, LocationState>(
          builder: (context, state) {
            
            if (state.current != null) {
              final position = LatLng(state.current!.lat, state.current!.lng);
              checkUserOnTrail(position);
            }

            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                //main map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: mapZoom,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${dotenv.env['MAPBOX_ACCESS_TOKEN']}',
                      userAgentPackageName: _appName,
                    ),
                    PolylineLayer(polylines: _buildPolylines()),
                    CurrentLocationLayer(),
                  ],
                ),
                Positioned(
                  top: 60.0,
                  right: 20.0,
                  child: FloatingActionButton(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    onPressed: _centerMapOnUser,
                    mini: true,
                    child: Icon(
                      Icons.my_location,
                      color: _isLocatingUser ? Colors.lightBlue : null,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: StatsRecordingCard(
                    trailName: trailName,
                    eta: _calculateEta(state),
                    elapsedTime: _elapsedTime,
                    isRecording: _stopwatch.isRunning,
                    onToggleRecording: _toggleStopwatch,
                    onStopRecording: _stopRecording,
                    stats: state,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class StatsRecordingCard extends StatefulWidget {
  final String trailName;
  final Duration eta;
  final Duration elapsedTime;
  final bool isRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback onStopRecording;
  final LocationState stats;

  const StatsRecordingCard({
    super.key,
    required this.trailName,
    required this.eta,
    required this.elapsedTime,
    required this.isRecording,
    required this.onToggleRecording,
    required this.onStopRecording,
    required this.stats,
  });

  static double collapsedSheetHeight(
    BuildContext context,
    String trailName,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final textStyle = Theme.of(context).textTheme.titleMedium;
    final availableWidth = mediaQuery.size.width - 36;
    final textPainter = TextPainter(
      text: TextSpan(text: trailName, style: textStyle),
      textDirection: Directionality.of(context),
      textAlign: TextAlign.center,
      maxLines: null,
    )..layout(maxWidth: availableWidth);

    const double collapsedTopPadding = 16;
    const double collapsedBottomPadding = 16;
    return collapsedTopPadding + textPainter.height + collapsedBottomPadding;
  }

  @override
  State<StatsRecordingCard> createState() => _StatsRecordingCardState();
}

class _StatsRecordingCardState extends State<StatsRecordingCard> {
  static const double _minSheetSize = 0.14;
  static const double _maxSheetSize = 0.80;
  static const double _detailsRevealOffset = 0.08;
  static const int _fractionalDigits = 2;

  double _sheetExtent = _minSheetSize;
  double _collapsedSheetSize = _minSheetSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final collapsedSheetSize = _calculateCollapsedSheetSize(
      context,
      widget.trailName,
    );
    if ((collapsedSheetSize - _collapsedSheetSize).abs() > 0.001) {
      _collapsedSheetSize = collapsedSheetSize;
      if (_sheetExtent < _collapsedSheetSize) {
        _sheetExtent = _collapsedSheetSize;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDetails = _sheetExtent >=
        math.min(_collapsedSheetSize + _detailsRevealOffset, _maxSheetSize);

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if ((notification.extent - _sheetExtent).abs() > 0.001) {
          setState(() {
            _sheetExtent = notification.extent;
          });
        }
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: _collapsedSheetSize,
        minChildSize: _collapsedSheetSize,
        maxChildSize: _maxSheetSize,
        expand: true,
        builder: (context, scrollController) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                  bottom: Radius.zero,
                ),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.25),
                ),
              ),
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                bottom: true,
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      showDetails ? 10 : 16,
                      18,
                      showDetails ? 14 : 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.trailName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                          softWrap: true,
                        ),
                        if (showDetails) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Container(
                              width: 44,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 10),
                          Column(
                            children: [
                              Text('Time', style: theme.textTheme.bodyMedium),
                              Text(
                                _formatDuration(widget.elapsedTime),
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: Column(
                              key: const ValueKey('expanded-stats'),
                              children: [
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 14),
                                Column(
                                  children: [
                                    Text('ETA', style: theme.textTheme.bodyMedium),
                                    Text(
                                      _formatDuration(widget.eta),
                                      style: theme.textTheme.titleLarge,
                                    )
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                            'Distance',
                                            style: theme.textTheme.bodyMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            widget.stats.getDistanceLabel(),
                                            style: theme.textTheme.titleLarge,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 48,
                                      child: VerticalDivider(
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                            'Elevation Gap',
                                            style: theme.textTheme.bodyMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.stats.getElevationGapLabel(),
                                            style: theme.textTheme.titleLarge,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: widget.onToggleRecording,
                                        label: widget.isRecording
                                            ? const Text('Pause')
                                            : const Text('Resume'),
                                        icon: widget.isRecording
                                            ? const Icon(Icons.pause)
                                            : const Icon(Icons.play_arrow),
                                        style: widget.isRecording
                                            ? ElevatedButton.styleFrom(
                                                backgroundColor: AppColors
                                                    .pauseButtonBackground,
                                                foregroundColor: AppColors
                                                    .pauseButtonForeground,
                                              )
                                            : ElevatedButton.styleFrom(
                                                backgroundColor: AppColors
                                                    .resumeButtonBackground,
                                                foregroundColor: AppColors
                                                    .pauseButtonForeground,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors
                                              .stopButtonBackground,
                                          foregroundColor: AppColors
                                              .stopButtonForeground,
                                        ),
                                        onPressed: widget.onStopRecording,
                                        label: const Text('Stop'),
                                        icon: const Icon(Icons.stop),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  static double _calculateCollapsedSheetHeight(
    BuildContext context,
    String trailName,
  ) {
    return StatsRecordingCard.collapsedSheetHeight(context, trailName);
  }

  double _calculateCollapsedSheetSize(
    BuildContext context,
    String trailName,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final collapsedHeight = _calculateCollapsedSheetHeight(context, trailName);
    final collapsedSize =
        collapsedHeight / mediaQuery.size.height + mediaQuery.padding.bottom / mediaQuery.size.height;

    return collapsedSize.clamp(_minSheetSize, _maxSheetSize);
  }

  double truncateToDecimalPlaces(num value) =>
      (value * math.pow(10, _fractionalDigits)).truncate() /
      math.pow(10, _fractionalDigits);
}
