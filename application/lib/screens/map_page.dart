import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geo;
import '../core/theme/app_colors.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: MainMapWidget());
  }
}

class MainMapWidget extends StatefulWidget {
  const MainMapWidget({super.key});

  @override
  State<MainMapWidget> createState() => _MainMapWidgetState();
}

class _MainMapWidgetState extends State<MainMapWidget> with AutomaticKeepAliveClientMixin {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineAnnotationManager;
  //list containing the top 10 trails
  List<Map<String, dynamic>> _foundTrails = [];

  //initial coordinates set to Rome, Italy as a fallback
  Position _currentCenter = Position(12.4822, 41.8967);

  //flag to indicate if the app is currently trying to locate the user
  bool _isLocating = false;
  //flag to indicate if the app is currently loading hiking trails
  bool _isLoadingTrails = false;
  //flag to indicate if the app is currently searching for a location
  bool _isSearchingLocation = false;

  //zoom level for the map
  double mapZoom = 12.0;

  //threshold to determine if the map is zoomed in enough to searrch for trails
  final double _minZoomThreshold = 13.0;
  bool _isZoomedInEnough = false;

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

  //indeex of the currently selected trail
  int _selectedTrailIndex = -1;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _isZoomedInEnough = mapZoom >= _minZoomThreshold;
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
        position: OrnamentPosition.BOTTOM_RIGHT,
        marginBottom: 5.0,
        marginRight: 10.0,
      ),
    );
    await _mapboxMap?.logo.updateSettings(
      LogoSettings(
        position: OrnamentPosition.BOTTOM_RIGHT,
        marginBottom: 5.0,
        marginRight: 40.0,
      ),
    );

    _mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: _currentCenter),
        zoom: mapZoom,
      ),
    );

    _checkInitialLocation();
  }

  //when the widget is first built, check if location services are enabled and permissions are granted, then fetch the current location
  Future<void> _checkInitialLocation() async {
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

    //fetch the current location and center the map on it
    geo.Position position = await geo.Geolocator.getCurrentPosition();
    _moveCameraTo(position.latitude, position.longitude, mapZoom);
  }

  //function to move the camera to a specific location with a given zoom level
  void _moveCameraTo(double lat, double lng, double zoom) {
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
    if (_polylineAnnotationManager == null || _foundTrails.isEmpty) return;

    await _polylineAnnotationManager!.deleteAll();
    List<PolylineAnnotationOptions> allLines = [];

    for (int i = 0; i < _foundTrails.length; i++) {
      final trail = _foundTrails[i];
      final isSelected = i == _selectedTrailIndex;

      allLines.add(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: trail['coordinates']),
          lineWidth: isSelected ? 6.0 : 3.0,
          lineColor: isSelected ? AppColors.selectedTrail.toARGB32() : AppColors.unselectedTrail.toARGB32(),
          lineJoin: LineJoin.ROUND,
          lineSortKey: isSelected ? 10.0 : 1.0,
        ),
      );
    }

    await _polylineAnnotationManager!.createMulti(allLines);
  }

  //function to fetch hiking trails currently rendered on the map and add markers
  Future<void> _fetchTrails() async {
    if (_mapboxMap == null) return;

    setState(() {
      _isLoadingTrails = true;
      _foundTrails.clear();
    });

    try {
      final width = MediaQuery.of(context).size.width;
      final height = MediaQuery.of(context).size.height;

      //restrict visible area to space between center map button and close button
      final topY = _centerMapButtonTopOffset + _centerMapButtonHeight;
      final bottomY = height - (_closeButtonBottomOffset + _closeButtonHeight);

      final features = await _mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(
          ScreenBox(
            min: ScreenCoordinate(x: 0, y: topY),
            max: ScreenCoordinate(x: width, y: bottomY),
          ),
        ),
        RenderedQueryOptions(
          layerIds: ['road-path', 'road-trail', 'road-steps', 'trails'],
          filter: null,
        ),
      );

      await _polylineAnnotationManager?.deleteAll();

      List<Map<String, dynamic>> tempTrails = [];
      int counter = 1;

      for (var qf in features) {
        if (tempTrails.length >= 10) break;

        final featureMap = qf?.queriedFeature.feature;
        if (featureMap != null) {
          final geometryMap = featureMap['geometry'] as Map<dynamic, dynamic>?;
          final propertiesMap =
              featureMap['properties'] as Map<dynamic, dynamic>?;

          if (geometryMap != null && geometryMap['type'] == 'LineString') {
            final coordinates = geometryMap['coordinates'] as List<dynamic>?;

            if (coordinates != null && coordinates.isNotEmpty) {
              List<Position> linePoints = coordinates.map((point) {
                return Position(point[0] as num, point[1] as num);
              }).toList();

              String trailName =
                  propertiesMap?['name'] ?? 'Hiking trail $counter';

              tempTrails.add({'name': trailName, 'coordinates': linePoints});
              counter++;
            }
          }
        }
      }

      setState(() {
        _foundTrails = tempTrails;
        if (_foundTrails.isNotEmpty) {
          _selectedTrailIndex = 0;
        }
      });

      if (_foundTrails.isNotEmpty) {
        await _drawPolylines();
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hiking trails found in this area. Try moving the map to a different location and searching again.',
            ),
          ),
        );
      }
    } catch (e) {
      print("Error occurred while searching for hiking trails: $e");
    } finally {
      if (mounted) setState(() => _isLoadingTrails = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    //dismiss the keyboard
    FocusScope.of(context).unfocus();

    //clear the search bar
    _searchController.clear();

    setState(() {
      _isSearchingLocation = true;
    });

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': _appName})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;

        if (data.isNotEmpty) {
          final double lat = double.parse(data[0]['lat']);
          final double lon = double.parse(data[0]['lon']);

          _moveCameraTo(lat, lon, mapZoom);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location not found. Please try a different search term.',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error occurred while searching for the location.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //needed for AutomaticKeepAliveClientMixin
    super.build(context);

    return Stack(
      children: [
        //main map
        MapWidget(
          key: const ValueKey("mapboxWidget"),
          textureView: true,
          styleUri: MapboxStyles.OUTDOORS,
          cameraOptions: CameraOptions(
            center: Point(coordinates: _currentCenter),
            zoom: mapZoom,
          ),
          onMapCreated: _onMapCreated,
          onCameraChangeListener: (cameraChangedEventData) async {
            final cameraState = await _mapboxMap?.getCameraState();
            if (cameraState != null && mounted) {
              final isEnough = cameraState.zoom >= _minZoomThreshold;
              if (isEnough != _isZoomedInEnough) {
                setState(() {
                  _isZoomedInEnough = isEnough;
                });
              }
            }
          },
        ),
        //search bar
        Positioned(
          top: 70.0,
          left: 16.0,
          right: 16.0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(30),
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => _searchLocation(value),
              decoration: InputDecoration(
                hintText: 'Search for a location...',
                hintStyle: Theme.of(context).textTheme.bodyMedium,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                suffixIcon: _isSearchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () =>
                            _searchLocation(_searchController.text),
                      ),
              ),
            ),
          ),
        ),
        //button to center the map on the user's current location
        Positioned(
          top: 130.0,
          right: 20.0,
          child: FloatingActionButton(
            backgroundColor: AppColors.background,
            onPressed: _centerMapOnUser,
            mini: true,
            child: Icon(
              Icons.my_location,
              color: _isLocating ? Colors.blue : null,
            ),
          ),
        ),
        //button to search for hiking trails in the current map view and show results
        Positioned(
          bottom: 40.0,
          left: 0,
          right: 0,
          child: _foundTrails.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 90.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: (_isLoadingTrails || !_isZoomedInEnough)
                          ? null
                          : _fetchTrails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.background,
                        elevation: 6,
                        disabledBackgroundColor: AppColors.deactivatedButtonBackground,
                        disabledForegroundColor: AppColors.deactivatedButtonText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      icon: _isLoadingTrails
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Icon(
                              !_isZoomedInEnough ? Icons.zoom_in : Icons.search,
                              size: 24,
                            ),
                      label: Text(
                        _isLoadingTrails
                            ? 'Searching...'
                            : (!_isZoomedInEnough
                                  ? 'Zoom in to search for trails'
                                  : 'Search for hiking trails in this area'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 130,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _foundTrails.length,
                    onPageChanged: (int index) {
                      setState(() {
                        _selectedTrailIndex = index;
                      });
                      _drawPolylines();
                    },
                    itemBuilder: (context, index) {
                      final trail = _foundTrails[index];
                      final isSelected = index == _selectedTrailIndex;

                      return GestureDetector(
                        onTap: () {
                          if (!isSelected) {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            // TODO: Apri dettagli del percorso
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: EdgeInsets.only(
                            right: 8.0,
                            left: 8.0,
                            top: isSelected ? 4.0 : 16.0,
                            bottom: isSelected ? 4.0 : 16.0,
                          ),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.hiking,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    trail['name'],
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        //close button to clear the drawn trail and reset the search results
        if (_foundTrails.isNotEmpty)
          Positioned(
            bottom: _closeButtonBottomOffset,
            right: 40.0,
            child: FloatingActionButton(
              backgroundColor: AppColors.background,
              mini: true,
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _polylineAnnotationManager!.deleteAll();
                    _foundTrails.clear();
                  });
                }
              },
              child: const Icon(Icons.keyboard_arrow_down, color: Colors.red),
            ),
          ),
      ],
    );
  }
}