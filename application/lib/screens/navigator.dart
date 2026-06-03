import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/screens/homepage.dart';
import 'package:application/services/map_management_service.dart';
import 'package:application/services/notification_service.dart';
import 'package:application/services/service_locator.dart';
import 'package:hike_core/hike_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:url_launcher/url_launcher.dart';
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
  static const double _movementSpeedThresholdMps = 0.4;
  static const Duration _movementSampleMaxAge = Duration(seconds: 12);

  final MapController _mapController = MapController();
  final HikeOffTrailDetector _offTrailDetector = HikeOffTrailDetector();

  late Stopwatch _stopwatch;
  late Timer _timer;
  Duration _elapsedTime = Duration.zero;
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

    Navigator.of(
      context,
      rootNavigator: true,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const Navigation()));
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
      DefaultMapManagementService().showServiceDialog(context);
      return;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (!mounted) return;

    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      DefaultMapManagementService().showPermissionDialog(context);
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

    final points = coordinates.expand((segment) => segment).toList();
    if (points.isEmpty) {
      throw ArgumentError('coordinates cannot be empty');
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  List<Polyline> _buildPolylines() {
    final trailColor = Theme.of(context).colorScheme.primary;

    return _trailSegments()
        .map(
          (segment) => Polyline(
            points: segment,
            strokeWidth: 4,
            color: trailColor,
          ),
        )
        .toList();
  }

  Future<void> _fitTrailInViewport() async {
    final segments = _trailSegments();
    if (segments.isEmpty) return;

    final bounds = _buildTrailBounds(segments);
    final center = LatLng(
      (bounds.north + bounds.south) / 2.0,
      (bounds.east + bounds.west) / 2.0,
    );

    if (!mounted) return;

    DefaultMapManagementService().moveCamera(
      center.latitude,
      center.longitude,
      mapZoom,
      _mapController,
    );
  }

  List<List<LatLng>> _trailSegments() {
    final subTrails = widget.trail['subTrails'];
    if (subTrails is! List) {
      return const [];
    }

    return subTrails.cast<List<LatLng>>();
  }

  void checkUserOnTrail(LatLng position) {
    final warning = _offTrailDetector.evaluate(
      position: position,
      subTrails: _trailSegments(),
      now: DateTime.now(),
    );

    if (warning == null) {
      return;
    }

    _showPathDistanceNotification(
      warning.distanceMeters,
      direction: warning.direction,
    );
  }

  DateTime _calculateEta(LocationState stats) {
    final now = DateTime.now();

    if (!_isUserMoving(stats)) {
      _lastEtaUpdateAt = now;
      return now.add(_remainingEta);
    }

    final lastUpdateAt = _lastEtaUpdateAt ?? now;
    _lastEtaUpdateAt = now;

    final nextRemaining = _remainingEta - now.difference(lastUpdateAt);
    _remainingEta = nextRemaining.isNegative ? Duration.zero : nextRemaining;

    return now.add(_remainingEta);
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
        child: BlocConsumer<LocationCubit, LocationState>(
          listenWhen: (previous, current) =>
              previous.isTracking &&
              current.isTracking &&
              current.current != null &&
              current.points.length > previous.points.length,
          listener: (context, state) {
            final position = LatLng(state.current!.lat, state.current!.lng);
            checkUserOnTrail(position);
          },
          builder: (context, state) {
            if (state.current != null) {
              final position = LatLng(state.current!.lat, state.current!.lng);
              checkUserOnTrail(position);
            }

            final liveStats = HikeLiveStats(
              elapsedTime: _elapsedTime,
              distanceMeters: state.distance,
              elevationGapMeters: state.elevationGap,
              eta: _calculateEta(state),
              recordingState: _stopwatch.isRunning
                  ? HikeRecordingState.recording
                  : HikeRecordingState.paused,
            );

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
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(
                            Uri.parse('https://openstreetmap.org/copyright'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 60.0,
                  right: 20.0,
                  child: FloatingActionButton(
                    heroTag: 'navigator-location-button',
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    onPressed: () async {
                      setState(() {
                        _isLocatingUser = true;
                      });
                      await DefaultMapManagementService().centerMap(
                        context,
                        _currentCenter,
                        _mapController,
                        zoom: mapZoom,
                      );
                      setState(() {
                        _isLocatingUser = false;
                      });
                    },
                    mini: true,
                    child: Icon(
                      Icons.my_location,
                      color: _isLocatingUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.shadow,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: StatsRecordingCard(
                    trailName: trailName,
                    stats: liveStats,
                    onToggleRecording: _toggleStopwatch,
                    onStopRecording: _stopRecording,
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
  final HikeLiveStats stats;
  final VoidCallback onToggleRecording;
  final VoidCallback onStopRecording;

  const StatsRecordingCard({
    super.key,
    required this.trailName,
    required this.stats,
    required this.onToggleRecording,
    required this.onStopRecording,
  });

  static double collapsedSheetHeight(BuildContext context, String trailName) {
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
    final showDetails =
        _sheetExtent >=
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
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSecondary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.trailName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          softWrap: true,
                        ),
                        if (showDetails) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 10),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Column(
                            children: [
                              Text('Time', style: theme.textTheme.bodyMedium),
                              Text(
                                widget.stats.elapsedLabel,
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Column(
                            children: [
                              Text('ETA', style: theme.textTheme.bodyMedium),
                              Text(
                                widget.stats.etaLabel,
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      widget.stats.distanceLabel,
                                      style: theme.textTheme.titleLarge,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 48,
                                child: VerticalDivider(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.35,
                                  ),
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
                                      widget.stats.elevationGapLabel,
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
                          HikeRecordingControls(
                            state: widget.stats.recordingState,
                            onStart: widget.onToggleRecording,
                            onPause: widget.onToggleRecording,
                            onStop: widget.onStopRecording,
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

  double _calculateCollapsedSheetSize(BuildContext context, String trailName) {
    final collapsedSheetHeight = StatsRecordingCard.collapsedSheetHeight(
      context,
      trailName,
    );
    final mediaQuery = MediaQuery.of(context);
    final collapsedSize = collapsedSheetHeight / mediaQuery.size.height;
    return collapsedSize.clamp(_minSheetSize, _maxSheetSize).toDouble();
  }
}
