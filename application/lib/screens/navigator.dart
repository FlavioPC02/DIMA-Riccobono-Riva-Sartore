import 'package:application/core/cubit/activity_cubit.dart';
import 'package:application/core/cubit/settings_cubit.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/services/notification_service.dart';
import 'package:application/widgets/user_location_listener.dart';
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
  State<NavigatorScreen> createState(){
    return _NavigatorScreenState();
  } 
}

class _NavigatorScreenState extends State<NavigatorScreen> {

  bool _isLocatingUser = false;
  static const double _offsetBound = 32;
  static const double _offTrailThresholdMeters = 50.0;
  static const double R = 6371000; // Earth radius in meters

  double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);

  final MapController _mapController = MapController();
  
  late Stopwatch _stopwatch;
  late Timer _timer;
  Duration _elapsedTime = Duration.zero;
  DateTime _lastOffTrailNotificationTime = DateTime.fromMillisecondsSinceEpoch(0);

  LatLng? _lastKnownPosition;
  double? _startElevation;
  double _distance = 0.0;
  double _elevationGap = 0.0;

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
    _stopwatch = Stopwatch();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_stopwatch.isRunning) return;
      setState(() {
        _elapsedTime = _stopwatch.elapsed;
      });
    });
    _buildMap();
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _toggleStopwatch() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
      } else {
        _stopwatch.start();
      }
      _elapsedTime = _stopwatch.elapsed;
    });
  }

  void _stopRecording() {
    setState(() {
      _stopwatch.stop();
      _elapsedTime = _stopwatch.elapsed;
    });

    final activity = widget.activity;
    activity.trackedDistance = _distance;
    activity.trackedElevationGap = _elevationGap;
    activity.trackedTime = _elapsedTime;

    context.read<ActivityCubit>().updateActivity(activity);
  }

  void _showPathDistanceNotification(int distance, {String? direction}) {
    final notificationsEnabled = context.read<SettingsCubit>().state.notifications;

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

  void _updateElevationGap(double currentElevation) {
    _startElevation ??= currentElevation;
    _elevationGap = currentElevation - _startElevation!;
  }

  //when the widget is first built, check if location services are enabled and permissions are granted, then fetch the current location
  Future<void> _centerMapOnTrail() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
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
    LatLng first = widget.trail['coordinates'].first.first;
    LatLng last = widget.trail['coordinates'].last.last;

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
    final coordinates = widget.trail['coordinates'];
    if (coordinates.isEmpty) return;

    final bounds = _buildTrailBounds(coordinates);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.fromLTRB(
          _offsetBound, 
          MediaQuery.of(context).padding.top + _offsetBound, 
          _offsetBound, 
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
          title: const Text('Location service required', textAlign: TextAlign.center),
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
                  child: const Text('Ignore', style: TextStyle(color: AppColors.errorText)),
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
          title: const Text('Location permission required', textAlign: TextAlign.center),
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
                  child: const Text('Ignore', style: TextStyle(color: AppColors.errorText)),
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
          color:AppColors.selectedTrail,
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
    final double dist2 = (px - projx) * (px - projx) + (py - projy) * (py - projy);
    // cross product of segment (dx,dy) and vector from proj->P => sign indicates side
    final double cross = dx * (py - projy) - dy * (px - projx);
    return {'distance': math.sqrt(dist2), 'side': cross};
  }

  void checkUserOnTrail(LatLng position) {
    final List<List<LatLng>> subTrails = widget.trail['subTrails'] as List<List<LatLng>>;
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

    if (distanceMeters > _offTrailThresholdMeters && now.difference(_lastOffTrailNotificationTime).inSeconds >= 60) {
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

  //calculate distance between last 2 recorded positions using Haversine formula
  double calculateDistanceHaversine(LatLng position, LatLng lkp) {
    double dLat = _degToRad(position.latitude - lkp.latitude);
    double dLng = _degToRad(position.longitude - lkp.longitude);

    double a = math.sin(dLat / 2.0) * math.sin(dLat / 2.0) +
      math.cos(_degToRad(lkp.latitude)) * math.cos(_degToRad(position.latitude)) *
      math.sin(dLng / 2.0) * math.sin(dLng / 2.0);

    double c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
    double distance = R * c;

    if(distance < 5.0) {
      return 0.0;
    } else {
      return distance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String trailName = widget.trail['name']?.toString() ?? 'Trail';

    return UserLocationListener(
      onLocationChanged: (userPosition) async {
        if (!_stopwatch.isRunning) return;

        if(userPosition != null) {
          checkUserOnTrail(userPosition.position);
          if (mounted) {
            setState(() {
              if (userPosition.positionAccuracy <= 20.0) {
                final newDistance = _lastKnownPosition == null 
                  ? 0.0 
                  : calculateDistanceHaversine(
                      userPosition.position, 
                      _lastKnownPosition!, 
                    );
                _distance += newDistance;
                _lastKnownPosition = userPosition.position;
              }
              if (userPosition.altitudeAccuracy <= 20.0) {
                _updateElevationGap(userPosition.altitude);
              }
            });
          }
        }
      },
      child: Stack(
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
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${dotenv.env['MAPBOX_ACCESS_TOKEN']}',
                userAgentPackageName: _appName,
              ),
              PolylineLayer(
                polylines: _buildPolylines(),
              ),
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
              elapsedTime: _elapsedTime,
              isRecording: _stopwatch.isRunning,
              onToggleRecording: _toggleStopwatch,
              onStopRecording: _stopRecording,
              distance: _distance,
              elevationGap: _elevationGap,
            ),
          ),
        ],
      ),
    );
  }
}

class StatsRecordingCard extends StatefulWidget {
  
  final String trailName;
  final Duration elapsedTime;
  final bool isRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback onStopRecording;
  final double distance;
  final double elevationGap;
  
  const StatsRecordingCard({
    super.key,
    required this.trailName,
    required this.elapsedTime,
    required this.isRecording,
    required this.onToggleRecording,
    required this.onStopRecording,
    required this.distance,
    required this.elevationGap,
  });

  @override
  State<StatsRecordingCard> createState() => _StatsRecordingCardState();
}

class _StatsRecordingCardState extends State<StatsRecordingCard> {
  static const double _minSheetSize = 0.14;
  static const double _initialSheetSize = 0.14;
  static const double _maxSheetSize = 0.80;
  static const double _detailsRevealThreshold = 0.18;
  static const int _fractionalDigits = 2;

  double _sheetExtent = _initialSheetSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDetails = _sheetExtent >= _detailsRevealThreshold;
    final distanceKm = widget.distance / 1000.0;

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
        initialChildSize: _initialSheetSize,
        minChildSize: _minSheetSize,
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
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                        Text(
                          widget.trailName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 10,),
                        Column(
                          children: [
                            Text(
                              'Time',
                              style: theme.textTheme.bodyMedium,
                            ),
                            //const SizedBox(height: 4),
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
                          child: showDetails
                              ? Column(
                                  key: const ValueKey('expanded-stats'),
                                  children: [
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
                                                '${truncateToDecimalPlaces(distanceKm) == 0.0 ? '--' : truncateToDecimalPlaces(distanceKm)} km',
                                                style: theme.textTheme.titleLarge,
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          height: 48,
                                          child: VerticalDivider(
                                            color: theme.colorScheme.outline.withValues(alpha: 0.35),
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
                                                '${truncateToDecimalPlaces(widget.elevationGap) == 0.0 ? '--' : truncateToDecimalPlaces(widget.elevationGap)} m',
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
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        //Pause/Resume button
                                        Expanded(
                                          flex: 2,
                                          child: ElevatedButton.icon(
                                            onPressed: widget.onToggleRecording,
                                            label: widget.isRecording 
                                              ? const Text('Pause')
                                              : const Text('Resume'),
                                            icon: widget.isRecording 
                                              ? Icon(Icons.pause)
                                              : Icon(Icons.play_arrow),
                                            style: widget.isRecording
                                              ? ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.pauseButtonBackground,
                                                foregroundColor: AppColors.pauseButtonForeground,
                                              )
                                              : ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.resumeButtonBackground,
                                                foregroundColor: AppColors.pauseButtonForeground,
                                              ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        //Stop button 
                                        Expanded(
                                          flex: 3,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.stopButtonBackground,
                                              foregroundColor: AppColors.stopButtonForeground,
                                            ),
                                            onPressed: widget.onStopRecording,
                                            label: Text('Stop'),
                                            icon: Icon(Icons.stop),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                )
                              : const SizedBox.shrink(key: ValueKey('collapsed-stats')),
                        ),
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

  double truncateToDecimalPlaces(num value) => (value * math.pow(10, 
   _fractionalDigits)).truncate() / math.pow(10, _fractionalDigits);
}