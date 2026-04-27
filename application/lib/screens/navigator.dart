import 'package:application/screens/map_page.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo;
import '../core/theme/app_colors.dart';

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
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineAnnotationManager;

  //initial coordinates set to Rome, Italy as a fallback
  Position _currentCenter = Position(12.4822, 41.8967);

  //flag to indicate if the app is currently trying to locate the user
  bool _isLocating = false;

  //zoom level for the map
  double mapZoom = 15.0;

  //controller for the search bar
  final TextEditingController _searchController = TextEditingController();

  //app name for user agent in API requests
  final String _appName = 'FlutterHikingApp/1.0';

  //constants for buttons positions used to calculate visible area
  static const double _centerMapButtonTopOffset = 130.0;
  static const double _centerMapButtonHeight = 56.0;
  static const double _closeButtonBottomOffset = 170.0;
  static const double _closeButtonHeight = 145.0;

  //keep the state of the map page alive when switching between screens
  @override
  bool get wantKeepAlive => true;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  //initialize the map and create the annotation manager
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _polylineAnnotationManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();

    //hide the compass
    await _mapboxMap?.compass.updateSettings(CompassSettings(enabled: false));

    //show position icon
    await _mapboxMap?.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        showAccuracyRing: true,
      ),
    );

    //move scale bar to bottom left and set it to use the metric system
    await _mapboxMap?.scaleBar.updateSettings(
      ScaleBarSettings(
        enabled: true,
        position: OrnamentPosition.BOTTOM_LEFT,
        isMetricUnits: true,
        marginBottom: 5.0,
        marginLeft: 10.0,
      ),
    );

    //move attribution and logo to bottom right
    await _mapboxMap?.attribution.updateSettings(
      AttributionSettings(
        enabled: false,
        position: OrnamentPosition.BOTTOM_RIGHT,
        marginBottom: 5.0,
        marginRight: 10.0,
      ),
    );
    await _mapboxMap?.logo.updateSettings(
      LogoSettings(
        enabled: false,
        position: OrnamentPosition.BOTTOM_RIGHT,
        marginBottom: 5.0,
        marginRight: 40.0,
      ),
    );

    //put map on trail and then zoom in/out to avoid unpleasant animation
    await _centerMapOnTrail();

    _mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: _currentCenter),
        zoom: mapZoom,
      ),
    );

    await _drawPolylines();
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
    Position trailCenter = _getPolylineCenter();
    setState(() {
      _currentCenter = trailCenter;
    });
  }

  //get the geometric center of the trail
  Position _getPolylineCenter() {
    Position first = widget.trail['coordinates'].first;
    Position last = widget.trail['coordinates'].last;

    num lat = (first.lat + last.lat) / 2.0;
    num lng = (first.lng + last.lng) / 2.0;

    return Position(lng, lat);
  }

  //returns the trail extremes points
  CoordinateBounds _buildTrailBounds(List<Position> coordinates) {
    if (coordinates.isEmpty) {
      throw ArgumentError('coordinates cannot be empty');
    }

    final first = coordinates.first;

    final bounds = coordinates.skip(1).fold(
      (
        minLat: first.lat.toDouble(),
        maxLat: first.lat.toDouble(),
        minLng: first.lng.toDouble(),
        maxLng: first.lng.toDouble(),
      ),
      (acc, p) {
        final lat = p.lat.toDouble();
        final lng = p.lng.toDouble();
        return (
          minLat: lat < acc.minLat ? lat : acc.minLat,
          maxLat: lat > acc.maxLat ? lat : acc.maxLat,
          minLng: lng < acc.minLng ? lng : acc.minLng,
          maxLng: lng > acc.maxLng ? lng : acc.maxLng,
        );
      },
    );

    return CoordinateBounds(
      southwest: Point(coordinates: Position(bounds.minLng, bounds.minLat)),
      northeast: Point(coordinates: Position(bounds.maxLng, bounds.maxLat)),
      infiniteBounds: false,
    );
  }
  
  //function which adjust mapZoom to fit the entire trail in the viewport
  Future<void> _fitTrailInViewport() async {
    if (_mapboxMap == null) return;

    final List<Position> coordinates =
        (widget.trail['coordinates'] as List).cast<Position>();
    if (coordinates.isEmpty) return;

    if (coordinates.length == 1) {
      await _mapboxMap!.easeTo(
        CameraOptions(
          center: Point(coordinates: coordinates.first),
          zoom: mapZoom,
        ),
        MapAnimationOptions(duration: 900),
      );
      return;
    }

    final bounds = _buildTrailBounds(coordinates);

    final camera = await _mapboxMap!.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(
        top: MediaQuery.of(context).padding.top + 20,
        left: 32,
        bottom: 32, //card height
        right: 32,
      ),
      null,
      null,
      null,
      null,
    );

    await _mapboxMap!.easeTo(camera, MapAnimationOptions(duration: 900));
  }

  //function to move the camera to a specific location with a given zoom level
  void _moveCameraTo(num lat, num lng, double zoom) {
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 1200),
    );
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
      _isLocating = true;
    });

    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();

    if (!serviceEnabled) {
      if (mounted) setState(() => _isLocating = false);
      _showLocationServiceDialog();
      return;
    }

    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLocating = false);
      _showLocationPermissionDialog();
      return;
    }

    geo.Position position = await geo.Geolocator.getCurrentPosition();
    Position newPos = Position(position.latitude, position.longitude);
    if (mounted) {
      setState(() {
        _currentCenter = newPos;
        _isLocating = false;
      });
      _moveCameraTo(position.latitude, position.longitude, mapZoom);
    }

    if (mounted) {
      setState(() => _isLocating = false);
    }
  }

  //function to draw polylines on the map for the found trails, highlighting the selected one
  Future<void> _drawPolylines() async {
    if (_polylineAnnotationManager == null) return;

    await _polylineAnnotationManager!.deleteAll();
    List<PolylineAnnotationOptions> allLines = [];

    final trail = widget.trail;

    allLines.add(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: trail['coordinates']),
        lineWidth: 6.0,
        lineColor: AppColors.selectedTrail.toARGB32(),
        lineJoin: LineJoin.ROUND,
        lineSortKey: 10.0,
      ),
    );

    await _polylineAnnotationManager!.createMulti(allLines);
  }

  @override
  Widget build(BuildContext context) {
    final String trailName = widget.trail['name']?.toString() ?? 'Trail';

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MapWidget(
                key: const ValueKey('navigatorMapBox'),
                textureView: true,
                styleUri: MapboxStyles.OUTDOORS,
                cameraOptions: CameraOptions(
                  center: Point(coordinates: _currentCenter),
                  zoom: mapZoom,
                ),
                onMapCreated: _onMapCreated,
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
                    color: _isLocating ? Colors.lightBlue : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 10,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Navigator',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      trailName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}