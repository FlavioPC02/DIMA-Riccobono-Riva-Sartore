import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geo;
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/theme/app_colors.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with AutomaticKeepAliveClientMixin {
  bool _isLocatingUser = false;
  bool _isLoadingTrails = false;
  bool _isSearchingLocation = false;

  final double _minZoomThreshold = 11.0;
  bool _isZoomedInEnough = true;
  
  static const double _centerMapButtonTopOffset = 186.0;
  static const double _closeButtonBottomOffset = 315.0;

  final MapController _mapController = MapController();

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _foundTrails = [];
  int _selectedTrailIndex = -1;
  late PageController _pageController;

  Timer? _debounce;
  List<Map<String, dynamic>> _locationSuggestions = [];
  bool _isFetchingSuggestions = false;

  //keep the state of the map page alive when switching between screens
  @override
  bool get wantKeepAlive => true;

  //to deal with potenial map tile loading errors
  DateTime? _lastTileErrorTime;
  bool _hasMapLoadError = false;
  bool _isRetryingMapLoad = false;
  Key _tileLayerKey = UniqueKey();

  //CONFIGURABLE VARIABLES

  //TODO: define final app name
  //app name used in API requests (user agent)
  final String _appName = 'FlutterHikingApp/1.0';

  //fallback location coordinates (Rome, Italy)
  LatLng _currentCenter = const LatLng(41.8967, 12.4822);

  //default zoom level for the map
  double mapZoom = 12.0;

  //search for trails in a location around a given radius
  final _searchRadius = 10000;

  //maximum number of trails to be displayed
  static const int _trailLimit = 10;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _checkInitialLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    _pageController.dispose();
    _debounce?.cancel();
    super.dispose();
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
    for (int i = 0; i < _foundTrails.length; i++) {
      final trail = _foundTrails[i];
      final isSelected = i == _selectedTrailIndex;

      for (List<LatLng> subTrailsCoordinates in trail['subTrails']) {
        allLines.add(
          Polyline(
            points: subTrailsCoordinates,
            strokeWidth: isSelected ? 6.0 : 3.0,
            color: isSelected ? AppColors.selectedTrail : AppColors.unselectedTrail,
          ),
        );
      }
    }
    //render selected line on top
    allLines.sort((a, b) => a.strokeWidth.compareTo(b.strokeWidth));
    return allLines;
  }

  //function to fetch hiking trails in the currently rendered location
  Future<void> _fetchTrails() async {
    setState(() {
      _isLoadingTrails = true;
      _foundTrails.clear();
    });

    try {
      final camera = _mapController.camera;
      
      final width = MediaQuery.of(context).size.width;
      final height = MediaQuery.of(context).size.height;

      final Point<double> topLeftPixel = Point(0.0, _centerMapButtonTopOffset);
      
      final Point<double> bottomRightPixel = Point(width, height - _closeButtonBottomOffset);

      final LatLng topLeft = camera.pointToLatLng(topLeftPixel);
      final LatLng bottomRight = camera.pointToLatLng(bottomRightPixel);

      final south = bottomRight.latitude;
      final north = topLeft.latitude;
      final west = topLeft.longitude;
      final east = bottomRight.longitude;

      final query = """
      [out:json][timeout:15];
      relation["route"="hiking"]($south,$west,$north,$east);
      out $_trailLimit geom;
      """;

      try{
        await _fetchOverpassResponse(query, 0, 0, false);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Network error. Check your connection and try again.')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoadingTrails = false);
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error occurred while searching for hiking trails')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingTrails = false);
    }
  }

  //function to search for the coordinates of a given location using the Nominatim API
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    //dismiss the keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isSearchingLocation = true;
    });

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': _appName})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;

        if (data.isNotEmpty) {
          final double lat = double.parse(data[0]['lat']);
          final double lon = double.parse(data[0]['lon']);

          await _fetchTrailsByLocation(lat, lon);
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

  //function to fetch hiking trails from the Overpass API using a given query, with retry logic for multiple servers and error handling
  Future<void> _fetchOverpassResponse(String query, double lat, double lon, bool shouldMoveCamera) async {
    
    final overpassUrl = Uri.parse('https://overpass-api.de/api/interpreter');
    final overpassUrl2 = Uri.parse('https://overpass.private.coffee/api/interpreter');

    final List<Uri> overpassServers = [
      overpassUrl,
      overpassUrl2,
    ];
    
    bool success = false;

    for (var url in overpassServers) {
      try {
        final response = await http.post(
          url, 
          body: query,
          headers: {'User-Agent': _appName} 
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          success = true;
          final data = json.decode(response.body);
          final List elements = data['elements'];

          if (elements.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No hiking trails found near the searched location. Try searching in a different area.')),
              );
            }
            return;
          }

          List<Map<String, dynamic>> tempTrails = [];
          int counter = 1;

          for (var rel in elements) {
            if (rel['type'] == 'relation') {
              String name = rel['tags']?['name'] ?? rel['tags']?['ref'] ?? 'Hiking Trail $counter';
                            
              List<List<LatLng>> subTrailCoordinates = [];

              if (rel['members'] != null) {
                for (var member in rel['members']) {
                  if (member['type'] == 'way' && member['geometry'] != null) {
                    List<LatLng> currentSubTrailCoordinates = [];
                    for (var geo in member['geometry']) {
                      currentSubTrailCoordinates.add(LatLng(geo['lat'].toDouble(), geo['lon'].toDouble()));
                    }
                    if (currentSubTrailCoordinates.isNotEmpty) {
                      subTrailCoordinates.add(currentSubTrailCoordinates);
                    }
                  }
                }
              }

              if (subTrailCoordinates.isNotEmpty) {
                tempTrails.add({
                  'id': rel['id'],
                  'name': name,
                  'subTrails': subTrailCoordinates
                });
              }
              counter++;
            }
          }

          setState(() {
            _pageController.dispose();
            _pageController = PageController(viewportFraction: 0.85);
            _foundTrails = tempTrails;
            if (_foundTrails.isNotEmpty) _selectedTrailIndex = 0;
          });

          if (_foundTrails.isNotEmpty) {
            if (mounted && shouldMoveCamera) {
              //zoom map to show the trails in the given radius
              double zoom = 14.5 - (log(_searchRadius / 1000) / log(2));
              _moveCameraTo(lat, lon, zoom);
            }
          }
          
          return; 
        } else {
          if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server error: Impossible to fetch trails. Automatically retrying')),
          );
        }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Network error. Check your connection and try again.')),
          );
        }
      } 
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server error: Impossible to fetch trails. Try again later')),
      );
    }
  }

  //function to fetch hiking trails around a specific location
  Future<void> _fetchTrailsByLocation(double lat, double lon) async {
    setState(() => _isLoadingTrails = true);

    //search for hiking trails, around the search location with a given radius and limit the resulted trails
    final query = """
    [out:json][timeout:15];
    relation["route"="hiking"](around:$_searchRadius,$lat,$lon);
    out $_trailLimit geom;
    """;

    try{
      await _fetchOverpassResponse(query, lat, lon, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingTrails = false);
    }
  }

  //function to manage debounce timer
  //Nominatim API has a rate limit of 1 request per second
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().length < 3) {
      setState(() => _locationSuggestions.clear());
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 800), () {
      _fetchLocationSuggestions(query);
    });
  }

  //function to fetch location suggestions
  Future<void> _fetchLocationSuggestions(String query) async {
    setState(() => _isFetchingSuggestions = true);

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': _appName})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (mounted) {
          if (_isSearchingLocation || _searchController.text.isEmpty) return;
          setState(() {
            _locationSuggestions = data.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error occurred while fetching location suggestions. Check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingSuggestions = false);
      }
    }
  }

  //function to retry loading the map tiles in case of loading errors
  Future<void> _retryMapLoad() async {
    setState(() {
      _isRetryingMapLoad = true;
    });

    try {
      //test if connection is back
      await http.get(Uri.parse('https://api.mapbox.com/')).timeout(const Duration(seconds: 3));
      
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      if (mounted) {
        setState(() {
          _isRetryingMapLoad = false;
          _hasMapLoadError = false;
          _tileLayerKey = UniqueKey();
        });
      }
    } catch (e) {
      //still no connection
      if (mounted) {
        setState(() {
          _isRetryingMapLoad = false;
        });
        
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading map tiles. Check your connection and try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //needed for AutomaticKeepAliveClientMixin
    super.build(context);

    return Scaffold(
      body: Stack(
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
              onPositionChanged: (camera, hasGesture) {
                final currentZoom = camera.zoom ?? mapZoom;
                final isEnough = currentZoom >= _minZoomThreshold;
                if (isEnough != _isZoomedInEnough) {
                  setState(() {
                    _isZoomedInEnough = isEnough;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                key: _tileLayerKey,
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${dotenv.env['MAPBOX_ACCESS_TOKEN']}',
                userAgentPackageName: _appName,
                errorTileCallback: (tile, error, stackTrace) {
                  final now = DateTime.now();
                  if (_lastTileErrorTime == null || now.difference(_lastTileErrorTime!).inSeconds > 5) {
                    _lastTileErrorTime = now;
                    
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _hasMapLoadError = true;
                        });
                        
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error loading map tiles. Check your connection and try again.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    });
                  }
                },
              ),
              PolylineLayer(
                polylines: _buildPolylines(),
              ),
            ],
          ),
          //button to reload the map in case of tile loading errors, shown only when a tile loading error occurs
          if (_hasMapLoadError)
            Positioned(
              top: 500.0,
              left: 150.0,
              right: 150.0,
              child: Center(
                child: _isRetryingMapLoad
                    ? Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorBackground,
                          foregroundColor: AppColors.errorText,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Reload map', style: TextStyle(fontSize: 20)),
                        onPressed: _retryMapLoad,
                      ),
              ),
            ),
          if (!_hasMapLoadError) ...[
            //button to center the map on the user's current location
            Positioned(
              top: 130.0,
              right: 20.0,
              child: FloatingActionButton(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                onPressed: _centerMapOnUser,
                mini: true,
                child: Icon(
                  Icons.my_location,
                  color: _isLocatingUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.shadow,
                ),
              ),
            ),
            //search bar and location suggestions
            Positioned(
              top: 70.0,
              left: 22.0,
              right: 22.0,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      enabled: !_isSearchingLocation,
                      onChanged: _onSearchChanged,
                      onSubmitted: (value) {
                        // cancel debounce timer before searching
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        setState(() {
                          _locationSuggestions.clear();
                          _isFetchingSuggestions = false;
                        });
                        if (!_isSearchingLocation) _searchLocation(value);
                      },
                      decoration: InputDecoration(
                        hintText: _isSearchingLocation ? 'Searching...' : 'Search for a location...',
                        hintStyle: Theme.of(context).textTheme.bodyMedium,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (context, value, child) {
                            if (_isFetchingSuggestions) {
                              return const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20, 
                                  height: 20, 
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            if (value.text.isNotEmpty) {
                              return IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _locationSuggestions.clear();
                                  });
                                },
                              );
                            }
                            return IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                FocusScope.of(context).requestFocus();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_locationSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8.0),
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.shadow,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _locationSuggestions.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1, 
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        itemBuilder: (context, index) {
                          final suggestion = _locationSuggestions[index];
                          final name = suggestion['display_name'] ?? 'Unknown location';
                          
                          return ListTile(
                            title: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              _searchController.text = name;
                              setState(() {
                                _locationSuggestions.clear();
                                _isSearchingLocation = true;
                              });

                              final lat = double.parse(suggestion['lat']);
                              final lon = double.parse(suggestion['lon']);                            
                              _moveCameraTo(lat, lon, 13.0);
                              _fetchTrailsByLocation(lat, lon).then((_) {
                                if (mounted) {
                                  setState(() => _isSearchingLocation = false);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
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
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            elevation: 6,
                            disabledBackgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                            disabledForegroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
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
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.hiking,
                                        color: Theme.of(context).colorScheme.primary,
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
          ],
          //close button to clear the drawn trail and reset the search results
          if (_foundTrails.isNotEmpty)
            Positioned(
              bottom: 170.0,
              right: 42.0,
              child: FloatingActionButton(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                mini: true,
                onPressed: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();

                  setState(() {
                    _foundTrails.clear();
                    _locationSuggestions.clear();
                  });
                },
                child: Icon(Icons.close, color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}