import 'package:application/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo;
import '../core/theme/app_colors.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NavigatorScreen extends StatefulWidget {
  //ottengo un Map<String, dynamic> id, name, coordinates
  final Map<String, dynamic> trail;
  
  const NavigatorScreen({
    required this.trail,
    super.key,
  });

  @override
  State<NavigatorScreen> createState(){
    return _NavigatorScreenState();
  } 
}

class _NavigatorScreenState extends State<NavigatorScreen> {

  bool _isLocatingUser = false;
  static const double _offsetBound = 32;

  final MapController _mapController = MapController();
  
  late Stopwatch _stopwatch;
  late Timer _timer;
  Duration _elapsedTime = Duration.zero;

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
    NotificationService.showNotification(title: 'Prova', body: 'notifica prova');
  }

  void _stopStopwatch() {
    setState(() {
      _stopwatch.stop();
      _elapsedTime = _stopwatch.elapsed;
    });
  }

  Future<void> _buildMap() async {
    await _centerMapOnTrail();
    _buildPolylines();
    await _fitTrailInViewport();
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

  @override
  Widget build(BuildContext context) {
    final String trailName = widget.trail['name']?.toString() ?? 'Trail';

    return Column(
      children: [
        Expanded(
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
                  onStopRecording: _stopStopwatch,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatsRecordingCard extends StatefulWidget {
  
  final String trailName;
  final Duration elapsedTime;
  final bool isRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback onStopRecording;
  
  const StatsRecordingCard({
    super.key,
    required this.trailName,
    required this.elapsedTime,
    required this.isRecording,
    required this.onToggleRecording,
    required this.onStopRecording,
  });

  @override
  State<StatsRecordingCard> createState() => _StatsRecordingCardState();
}

class _StatsRecordingCardState extends State<StatsRecordingCard> {
  static const double _minSheetSize = 0.14;
  static const double _initialSheetSize = 0.14;
  static const double _maxSheetSize = 0.80;
  static const double _detailsRevealThreshold = 0.18;

  double _sheetExtent = _initialSheetSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDetails = _sheetExtent >= _detailsRevealThreshold;

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
                                                '-- km',
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
                                                '-- m',
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
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        //Stop button 
                                        Expanded(
                                          flex: 3,
                                          child: ElevatedButton.icon(
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
}