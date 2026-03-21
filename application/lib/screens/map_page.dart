import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapWidget(),
    );
  }
}

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  //controller to change map position
  final MapController _mapController = MapController();
  //initial coordinates set to Rome, Italy as a fallback
  LatLng _currentCenter = const LatLng(41.8967, 12.4822); 
  //flag to indicate if location is being fetched
  bool _isLoading = true;
  //flag to indicate if the app is currently trying to locate the user
  bool _isLocating = false;
  //zoom level for the map
  double mapZoom = 12.0;

  @override
  void initState() {
    super.initState();
    _checkInitialLocation();
  }

  //when the widget is first built, check if location services are enabled and permissions are granted, then fetch the current location
  Future<void> _checkInitialLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      _showLocationServiceDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      _showLocationPermissionDialog();
      return;
    }

    //current location is fetched only if services are enabled and permissions are granted, otherwise the map will be centered on the fallback coordinates
    setState(() => _isLoading = true);
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentCenter = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });

  }

  //dialog shown when location services are disabled
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Location service required'),
          content: const Text('Enable GPS to obtain the current location.'),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();  
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  //dialog shown when location permissions are denied
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Location permission required'),
          content: const Text('Without enabling the permission, it is not possible to obtain the current location.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Ignore'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); 
                //open app settings to allow the user to grant location permissions
                Geolocator.openAppSettings();
              },
              child: const Text('Enable location permission'),
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

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (!serviceEnabled) {
      setState(() => _isLocating = false);
      _showLocationServiceDialog();
      return;
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _isLocating = false);
      _showLocationPermissionDialog();
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    LatLng newPos = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentCenter = newPos;
    });

    setState(() {
      _currentCenter = newPos;
      _isLocating = false;
    });

    //move the map to the new position while keeping the current zoom level
    double currentZoom = _mapController.camera.zoom;
    _mapController.move(newPos, currentZoom);
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } 

    return Stack(
      children: [
        //first layer map + hiking trails + attributions
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentCenter,
            initialZoom: mapZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            backgroundColor: Colors.transparent,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.iltuonome.lamiaapp',
            ),
            TileLayer(
              urlTemplate: 'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.iltuonome.lamiaapp',
            ),
            RichAttributionWidget(
              showFlutterMapAttribution: false, 
              attributions: [
                TextSourceAttribution('Map by OpenStreetMap'),
                TextSourceAttribution('Hiking routes by Waymarked Trails'),
              ],
            ),
          ],
        ),
        //second layer floating button
        Positioned(
          top: 50.0,
          right: 20.0,
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            onPressed: _centerMapOnUser,
            mini: true,
            child: Icon(
              Icons.my_location,
              color: _isLocating ? Colors.blue : null,
            ),
          ),
        ),
      ],
    );
  }
}