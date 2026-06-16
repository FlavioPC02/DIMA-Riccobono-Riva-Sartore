import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/location_cubit.dart';
import 'package:application/services/phone_wear_sync.dart';
import 'package:application/services/service_locator.dart';
import 'package:application/widgets/stats_recording_card.dart';
import 'package:hike_core/hike_core.dart';
import 'package:application/core/cubit/profile_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/screens/homepage.dart';
import 'package:application/services/map_management_service.dart';
import 'package:application/services/notification_service.dart';
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

class _NavigatorScreenState extends State<NavigatorScreen> with WidgetsBindingObserver {
  static const double _offsetBound = 32;
  static const double _offsetBoundTop = 37;
  static const double _offTrailThresholdMeters = 50.0;
  static const double R = 6371000; // Earth radius in meters

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  final MapController _mapController = MapController();

  DateTime _lastOffTrailNotificationTime = DateTime.fromMillisecondsSinceEpoch(
    0,
  );

  late final LocationCubit _locationCubit;

  bool _isLocatingUser = false;

  //CONFIGURABLE VARIABLES

  //app name used in API requests (user agent)
  final String _appName = 'FlutterHikingApp/1.0';

  //fallback location coordinates (Rome, Italy)
  LatLng _currentCenter = const LatLng(41.8967, 12.4822);

  //default zoom level for the map
  double mapZoom = 12.0;
  late Timer _elapsedTimer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _locationCubit = sl<LocationCubit>();

    // If the hike was already stopped (e.g. from watch while app was in background)
    // navigate away as soon as the first frame is rendered.
    if (_locationCubit.pendingNavigation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _locationCubit.consumeNavigation();
      });
    }

    _locationCubit.setInitialEta(Duration(minutes: widget.activity.durationMinutes));
    _locationCubit.setTotalDistance(widget.activity.distanceKm * 1000);

    sl<PhoneWearSyncService>().sendNavigationPrompt();

    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final newElapsed = _locationCubit.elapsed;
      // Only rebuild when the second boundary crosses — 10 checks per second
      // but only ~1 rebuild per second for the timer display.
      if (newElapsed.inSeconds != _elapsedTime.inSeconds) {
        setState(() {
          _elapsedTime = newElapsed;
        });
      }
    });

    _buildMap();
    _registerLocationCubitCallbacks();
    _locationCubit.startTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationCubit.unregisterStopCallbacks();
    _locationCubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _locationCubit.consumeNavigation();
    }
  }

  void _registerLocationCubitCallbacks() {
    final activityCubit = context.read<ActivityCubit>();
    final profileCubit = context.read<ProfileCubit>();
    final activity = widget.activity;

    _locationCubit.registerStopCallbacks(
      onActivitySaved:
          ({
            required double distance,
            required double elevationGap,
            required Duration elapsed,
          }) async {
            activity.trackedDistance = distance;
            activity.trackedElevationGap = elevationGap;
            activity.trackedTime = elapsed;
            activity.status = ActivityStatus.completed;

            if (activity.id.isEmpty) {
              await activityCubit.addActivity(activity);
            } else {
              await activityCubit.updateActivity(activity);
            }

            // Profile XP update — also safe to call without context
            final profile = profileCubit.state;
            profileCubit.updateXp(profile.xp + activity.xpEarned);
          },

      onNavigateAfterStop: () {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (_) => const Navigation()),
        );
      },
    );
  }

  Future<void> _pauseOrResumeRecording() async {
    if (_locationCubit.isRunning) {
      await _locationCubit.pauseTracking();
    } else {
      await _locationCubit.resumeTracking();
    }
  }

  Future<void> _stopRecording() async {
    await _locationCubit.stopAndSave(navigate: true);
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

  @override
  Widget build(BuildContext context) {
    final String trailName = widget.trail['name']?.toString() ?? 'Trail';

    return BlocProvider.value(
      value: _locationCubit,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _locationCubit.stopAndSave(navigate: true);
        },
        child: BlocConsumer<LocationCubit, LocationState>(
          listenWhen: (previous, current) =>
              current.current != null &&
              previous.isTracking &&
              current.isTracking &&
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
                      color: _isLocatingUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.shadow,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: StatsRecordingCard(
                    trailName: trailName,
                    elapsedTime: _elapsedTime,
                    isRecording: _locationCubit.isRunning,
                    onToggleRecording: _pauseOrResumeRecording,
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
