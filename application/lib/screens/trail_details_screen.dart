import 'package:application/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TrailDetailsScreen extends StatefulWidget {
  final int trailId;
  final String trailName;

  const TrailDetailsScreen({
    super.key,
    required this.trailId,
    required this.trailName,
  });

  @override
  State<TrailDetailsScreen> createState() => _TrailDetailsPageState();
}

class _TrailDetailsPageState extends State<TrailDetailsScreen> {
  bool _isLoading = true;

  // Variabili di stato separate per i dati della relazione e quelli aggregati dalle way
  Map<String, dynamic>? _relationTags;
  Set<String> _surfaces = {};
  String? _maxIncline;
  String? _estimatedDistance;
  String? _estimatedDuration;
  
  String? _errorMessage;

  // TODO: define final app name
  final String _appName = 'FlutterHikingApp/1.0';

  @override
  void initState() {
    super.initState();
    _fetchTrailDetails();
  }

  Future<void> _fetchTrailDetails() async {
    final query = """
      [out:json][timeout:15];
      relation(${widget.trailId});
      out tags geom; 
      way(r);
      out tags geom;
    """;

    final overpassUrl = Uri.parse('https://overpass-api.de/api/interpreter');

    try {
      final response = await http.post(
        overpassUrl,
        body: query,
        headers: {'User-Agent': _appName},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        Map<String, dynamic>? relTags;
        Set<String> tempSurfaces = {};
        double tempMaxInclineValue = 0.0;
        String? tempMaxInclineStr;  

        for (var el in elements) {
          if (el['type'] == 'relation' && el['tags'] != null) {
            relTags = el['tags'];
          } else if (el['type'] == 'way' && el['tags'] != null) {
            if (el['tags']['surface'] != null) {
              tempSurfaces.add(el['tags']['surface']);
            }
            if (el['tags']['incline'] != null) {
              String inclineVal = el['tags']['incline'].toString().toLowerCase().trim();
              
              if (inclineVal != 'up' && inclineVal != 'down') {
                String numericPart = inclineVal.replaceAll(RegExp(r'[^0-9.]'), '');
                if (numericPart.isNotEmpty) {
                  double? parsedValue = double.tryParse(numericPart);
                  if (parsedValue != null && parsedValue > tempMaxInclineValue) {
                    tempMaxInclineValue = parsedValue;
                    tempMaxInclineStr = inclineVal.replaceAll('+', '').replaceAll('-', '');
                  }
                }
              }
            }
          }
        }

        List<LatLng> allPoints = [];

        for (var el in elements) {
          if (el['type'] == 'way' && el['geometry'] != null) {
            for (var geo in el['geometry']) {
              allPoints.add(LatLng(geo['lat'].toDouble(), geo['lon'].toDouble()));
            }
          }
        }

        if (allPoints.isNotEmpty) {
          double meters = 0.0;
          final distanceCalc = const Distance();

          for (var el in elements) {
            if (el['type'] == 'way' && el['geometry'] != null) {
              List<LatLng> wayPoints = [];
              for (var geo in el['geometry']) {
                wayPoints.add(LatLng(geo['lat'].toDouble(), geo['lon'].toDouble()));
              }
              
              for (int i = 0; i < wayPoints.length - 1; i++) {
                meters += distanceCalc.as(
                  LengthUnit.Meter,
                  wayPoints[i],
                  wayPoints[i + 1],
                );
              }
            }
          }

          if (meters > 0) {
            if (_relationTags?['distance'] == null) {
              double estimatedKm = (meters / 1000); 
              _estimatedDistance = "${estimatedKm.toStringAsFixed(1)} km (stima)";
            }

            if (_relationTags?['duration'] == null && _relationTags?['time'] == null) {
              double km = (_relationTags?['distance'] != null) 
                  ? double.tryParse(_relationTags!['distance'].replaceAll(RegExp(r'[^0-9.]'), '')) ?? (meters / 1000)
                  : (meters / 1000);

              //average hiking speed: 4 km/h
              double hours = km / 4.0;
              int totalMinutes = (hours * 60).toInt();
              int h = totalMinutes ~/ 60;
              int m = totalMinutes % 60;
              
              _estimatedDuration = "${h}h ${m}m (estimated)";
            }
          }
        }

        if (relTags != null) {
          setState(() {
            _relationTags = relTags;
            _surfaces = tempSurfaces;
            _maxIncline = tempMaxInclineStr;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Informations not available.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error occurred while retriving trail details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trailName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.errorText),
          ),
        ),
      );
    }

    if (_relationTags == null || _relationTags!.isEmpty) {
      return const Center(child: Text('Additional informations not available.'));
    }

    return Column(
      children: [
        _buildHighlightedStats(),
        const Divider(height: 1, thickness: 1),
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildInfoTile('Operator', _relationTags?['operator']),
              _buildInfoTile('Website', _relationTags?['website']),
              _buildInfoTile('Description', _relationTags?['description']),
              _buildInfoTile('Notes', _relationTags?['note']),
              _buildInfoTile('Surfaces', _surfaces.isNotEmpty ? _surfaces.join(', ') : null),
              _buildInfoTile('Maximum inclination', _maxIncline),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String title, String? value) {
    if (value == null || value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedStats() {
    String distance = _relationTags?['distance'] ?? _estimatedDistance ?? 'N/D';
    if (distance != 'N/D' && distance != _estimatedDistance) {
      String numericPart = distance.replaceAll(RegExp(r'[^0-9.]'), '');
      double? distValue = double.tryParse(numericPart);
      
      if (distValue != null) {
        distance = '${distValue.toStringAsFixed(1)} km';
      } else if (!distance.toLowerCase().contains('km')) {
        distance = '$distance km';
      }
    }

    String duration = _relationTags?['duration'] ?? _relationTags?['time'] ?? _estimatedDuration ?? 'N/D';
    if (duration != 'N/D' && duration != _estimatedDuration) {
      if (duration.contains(':')) {
        List<String> parts = duration.split(':');
        if (parts.length >= 2) {
          int? h = int.tryParse(parts[0]);
          int? m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            duration = '${h}h ${m}m';
          }
        }
      } 
      else if (!duration.toLowerCase().contains('h') && !duration.toLowerCase().contains('m')) {
        duration = '$duration h';
      }
    }

    final String difficulty = _relationTags?['sac_scale'] ?? _relationTags?['cai_scale'] ?? 'N/D';
    
    final String ascent = _relationTags?['ascent'] ?? 'N/D';
    String elevationStr = 'N/D';
    if (ascent != 'N/D') {
      elevationStr = '+$ascent m';
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: [
          _buildStatCard(Icons.route, 'Distance', distance),
          _buildStatCard(Icons.timer_outlined, 'Duration', duration),
          _buildStatCard(Icons.landscape, 'Difficulty', difficulty),
          _buildStatCard(Icons.height, 'Elevation', elevationStr),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.secondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.8)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value, 
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}