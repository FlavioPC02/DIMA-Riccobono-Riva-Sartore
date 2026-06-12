import 'package:application/core/theme/app_colors.dart';
import 'package:application/services/helpers/trail_details_screen_helper.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:application/services/weather_service.dart';
import 'package:lottie/lottie.dart';
import 'package:application/screens/navigator.dart';
import 'package:application/core/models/activity.dart';
import 'package:application/core/models/trail_point.dart';
import 'package:application/screens/add_activity_page.dart';

class TrailDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> trail;

  const TrailDetailsScreen({super.key, required this.trail});

  @override
  State<TrailDetailsScreen> createState() => _TrailDetailsPageState();
}

class _TrailDetailsPageState extends State<TrailDetailsScreen> {
  bool _isLoading = true;

  bool _isFavorite = false;

  Map<String, dynamic>? _relationTags;
  Set<String> _surfaces = {};
  String? _maxIncline;
  String? _estimatedAscent;
  ActivityDifficulty difficulty = ActivityDifficulty.easy;

  String? _errorMessage;

  List<double>? _elevations;
  List<double>? _distances;
  bool _isLoadingElevations = true;

  double _calculatedMeters = 0.0;
  double _distanceKm = 0.0;
  int _durationMinutes = 0;
  int _difficulty = 0;

  List<Map<String, dynamic>>? _weatherForecast;
  bool _isLoadingWeather = true;
<<<<<<< HEAD
=======
  String _lottieAsset(int code) {
    if (code == 800) return 'assets/lottie/clear.json';
    if (code == 801) return 'assets/lottie/few_clouds.json';
    if (code >= 802) return 'assets/lottie/cloudy.json';
    if (code >= 700) return 'assets/lottie/fog.json';
    if (code >= 600) return 'assets/lottie/snow.json';
    if (code >= 500) return 'assets/lottie/rain.json';
    if (code >= 300) return 'assets/lottie/drizzle.json';
    return 'assets/lottie/thunderstorm.json';
  }
>>>>>>> 52ad0c6 (Added start button and implemented local trail)

  final String _appName = 'FlutterHikingApp/1.0';

  @override
  void initState() {
    super.initState();
    _fetchTrailDetails();
  }

  Future<void> _fetchTrailDetails() async {
    final query =
        """
      [out:json][timeout:15];
      relation(${widget.trail['id']});
      out tags geom; 
      way(r);
      out tags geom;
    """;

    final overpassServers = [
      Uri.parse('https://overpass-api.de/api/interpreter'),
      Uri.parse('https://overpass.private.coffee/api/interpreter'),
      Uri.parse('https://overpass.kumi.systems/api/interpreter'),
    ];

    bool hadNetworkError = false;
    int? lastStatusCode;

    for (final overpassUrl in overpassServers) {
      try {
        final response = await http
            .post(overpassUrl, body: query, headers: {'User-Agent': _appName})
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          lastStatusCode = response.statusCode;
          continue;
        }

        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        Map<String, dynamic>? relTags;
        Set<String> tempSurfaces = {};
        double tempMaxInclineValue = 0.0;
        String? tempMaxInclineStr;

        List<List<LatLng>> segments = [];

        for (var el in elements) {
          if (el['type'] == 'relation' && el['tags'] != null) {
            relTags = el['tags'];
          } else if (el['type'] == 'way' && el['tags'] != null) {
            if (el['tags']['surface'] != null) {
              tempSurfaces.add(el['tags']['surface']);
            }
            if (el['tags']['incline'] != null) {
              String inclineVal = el['tags']['incline']
                  .toString()
                  .toLowerCase()
                  .trim();
              if (inclineVal != 'up' && inclineVal != 'down') {
                String numericPart = inclineVal.replaceAll(
                  RegExp(r'[^0-9.]'),
                  '',
                );
                if (numericPart.isNotEmpty) {
                  double? parsedValue = double.tryParse(numericPart);
                  if (parsedValue != null &&
                      parsedValue > tempMaxInclineValue) {
                    tempMaxInclineValue = parsedValue;
                    tempMaxInclineStr = inclineVal
                        .replaceAll('+', '')
                        .replaceAll('-', '');
                  }
                }
              }
            }
          }

          if (el['type'] == 'way' && el['geometry'] != null) {
            List<LatLng> wayPoints = [];
            for (var geo in el['geometry']) {
              wayPoints.add(
                LatLng(geo['lat'].toDouble(), geo['lon'].toDouble()),
              );
            }
            if (wayPoints.isNotEmpty) segments.add(wayPoints);
          }
        }

        double meters = 0.0;
        final distanceCalc = const Distance();
        for (var seg in segments) {
          for (int i = 0; i < seg.length - 1; i++) {
            meters += distanceCalc.as(LengthUnit.Meter, seg[i], seg[i + 1]);
          }
        }

        List<LatLng> allPoints = TrailDetailsScreenHelper.stitchSegments(segments);

<<<<<<< HEAD
        _calculatedMeters = meters;
        _distanceKm = TrailDetailsScreenHelper.getDistanceKm(relTags?['distance'], meters);
        _durationMinutes = TrailDetailsScreenHelper.getDurationMinutes(relTags?['duration'], relTags?['time'], _distanceKm);
        
=======
          while (segments.isNotEmpty) {
            double minDistance = double.infinity;
            int bestIndex = -1;
            int attachMode = -1;

            LatLng currentEnd = allPoints.last;
            LatLng currentStart = allPoints.first;

            for (int i = 0; i < segments.length; i++) {
              var seg = segments[i];

              double dEndFirst = distanceCalc.as(
                LengthUnit.Meter,
                currentEnd,
                seg.first,
              );
              if (dEndFirst < minDistance) {
                minDistance = dEndFirst;
                bestIndex = i;
                attachMode = 0;
              }

              double dEndLast = distanceCalc.as(
                LengthUnit.Meter,
                currentEnd,
                seg.last,
              );
              if (dEndLast < minDistance) {
                minDistance = dEndLast;
                bestIndex = i;
                attachMode = 1;
              }

              double dStartLast = distanceCalc.as(
                LengthUnit.Meter,
                currentStart,
                seg.last,
              );
              if (dStartLast < minDistance) {
                minDistance = dStartLast;
                bestIndex = i;
                attachMode = 2;
              }

              double dStartFirst = distanceCalc.as(
                LengthUnit.Meter,
                currentStart,
                seg.first,
              );
              if (dStartFirst < minDistance) {
                minDistance = dStartFirst;
                bestIndex = i;
                attachMode = 3;
              }
            }

            if (minDistance > 1000) {
              break;
            }

            var bestSeg = segments[bestIndex];
            if (attachMode == 0) {
              allPoints.addAll(bestSeg.skip(1));
            } else if (attachMode == 1) {
              allPoints.addAll(bestSeg.reversed.skip(1));
            } else if (attachMode == 2) {
              allPoints.insertAll(0, bestSeg.sublist(0, bestSeg.length - 1));
            } else if (attachMode == 3) {
              allPoints.insertAll(0, bestSeg.reversed.skip(1));
            }

            segments.removeAt(bestIndex);
          }
        }

        if (meters > 0) {
          if (relTags?['distance'] == null) {
            _distanceKm = (meters / 1000);
            _estimatedDistance = "${_distanceKm.toStringAsFixed(1)} km";
          }

          if (relTags?['duration'] == null && relTags?['time'] == null) {
            double km = (relTags?['distance'] != null)
                ? double.tryParse(
                        relTags!['distance'].replaceAll(RegExp(r'[^0-9.]'), ''),
                      ) ??
                      (meters / 1000)
                : (meters / 1000);
            double hours = km / 4.0;
            _durationMinutes = (hours * 60).toInt();
            _estimatedDuration =
                "${_durationMinutes ~/ 60}h ${_durationMinutes % 60}m";
          }
        }

>>>>>>> 52ad0c6 (Added start button and implemented local trail)
        if (allPoints.isNotEmpty) {
          _fetchElevations(allPoints);
          _fetchWeather(allPoints.first);
        } else {
          setState(() {
            _isLoadingWeather = false;
            _isLoadingElevations = false;
          });
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

        return;
      } catch (e) {
        hadNetworkError = true;
      }
    }

    if (!mounted) return;
    setState(() {
      _errorMessage = lastStatusCode == null && hadNetworkError
          ? 'Network error. Check your connection and try again.'
          : 'Trail details are temporarily unavailable. Try again later.';
      _isLoading = false;
      _isLoadingWeather = false;
      _isLoadingElevations = false;
    });
  }

  Future<void> _fetchElevations(List<LatLng> points) async {
    if (points.isEmpty) {
      setState(() => _isLoadingElevations = false);
      return;
    }

    const int maxPoints = 50;
    final sampledData = TrailDetailsScreenHelper.samplePoints(points, maxPoints);

    List<LatLng> sampledPoints = sampledData['points'];
    List<double> sampledDistances = sampledData['distances'];

    try {
      final url = Uri.parse('https://api.open-elevation.com/api/v1/lookup');

      final body = json.encode({
        "locations": sampledPoints
            .map((p) => {"latitude": p.latitude, "longitude": p.longitude})
            .toList(),
      });

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        double calculatedAscent = 0.0;
        for (int i = 1; i < results.length; i++) {
          double prev = (results[i - 1]['elevation'] as num).toDouble();
          double curr = (results[i]['elevation'] as num).toDouble();
          double diff = curr - prev;
          if (diff > 1.5) {
            calculatedAscent += diff;
          }
        }

        setState(() {
          _elevations = results
              .map((e) => (e['elevation'] as num).toDouble())
              .toList();
          _distances = sampledDistances;
          _estimatedAscent = calculatedAscent.round().toString();
          _isLoadingElevations = false;
        });
      } else {
        setState(() => _isLoadingElevations = false);
      }
    } catch (e) {
      setState(() => _isLoadingElevations = false);
    }
  }

  Future<void> _fetchWeather(LatLng location) async {
    try {
      final forecast = await WeatherService().fetchMultipleDaysForecast(
        location.latitude,
        location.longitude,
      );

      if (mounted) {
        setState(() {
          _weatherForecast = forecast;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  int _updateDifficulty() {
    int level = TrailDetailsScreenHelper.calculateDifficultyLevel(
      _relationTags, _distanceKm, double.tryParse(_estimatedAscent ?? '0') ?? 0.0
    );
    if (level == 1) { 
      difficulty = ActivityDifficulty.easy; 
    } else if (level == 2) { 
      difficulty = ActivityDifficulty.moderate; 
    } else { 
      difficulty = ActivityDifficulty.hard; 
    }
<<<<<<< HEAD
    return level;
=======

    if (sac != null) {
      if (sac.contains('alpine') ||
          sac.contains('t4') ||
          sac.contains('t5') ||
          sac.contains('t6')) {
        return 3;
      }
      if (sac.contains('mountain_hiking') ||
          sac.contains('t2') ||
          sac.contains('t3')) {
        return 2;
      }
      if (sac.contains('hiking') || sac.contains('t1')) return 1;
    }

    String distanceStr =
        _relationTags?['distance'] ?? _estimatedDistance ?? '0';
    String ascentStr = _relationTags?['ascent'] ?? _estimatedAscent ?? '0';

    String numDist = distanceStr.replaceAll(RegExp(r'[^0-9.]'), '');
    String numAscent = ascentStr.replaceAll(RegExp(r'[^0-9.]'), '');

    double distanceKm = double.tryParse(numDist) ?? 0.0;
    double ascentM = double.tryParse(numAscent) ?? 0.0;

    if (distanceKm == 0 && ascentM == 0) return 0;

    double effortScore = distanceKm + (ascentM / 100);

    if (effortScore < 7.0) {
      difficulty = ActivityDifficulty.easy;
      return 1;
    }
    if (effortScore < 14.0) {
      difficulty = ActivityDifficulty.moderate;
      return 2;
    }
    difficulty = ActivityDifficulty.hard;
    return 3;
>>>>>>> 52ad0c6 (Added start button and implemented local trail)
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.trail['name'],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: (_isFavorite ? const Icon(Icons.star) : 
            const Icon(Icons.star_border)),
            color: Colors.yellow,
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
            },
          )
        ],
      ),
      body: Stack(
        children: [_buildBody(), if (!_isLoading) _buildFloatingButtons()],
      ),
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
      return const Center(
        child: Text('Additional informations not available.'),
      );
    }

    return Column(
      children: [
        _buildHighlightedStats(),
<<<<<<< HEAD
        const Divider(height: 1, thickness: 2),
        
=======
        const Divider(height: 1, thickness: 1),

>>>>>>> 52ad0c6 (Added start button and implemented local trail)
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.0, MediaQuery.textScalerOf(context).scale(20), 16.0, 16.0),
            children: [
              _buildWeatherBox(),
              _buildElevationChart(),
              if (_elevations != null && _elevations!.isNotEmpty)
                const SizedBox(height: 16),
              _buildInfoTile('Operator', _relationTags?['operator']),
              _buildInfoTile('Website', _relationTags?['website']),
              _buildInfoTile('Description', _relationTags?['description']),
              _buildInfoTile('Notes', _relationTags?['note']),
              _buildInfoTile(
                'Surfaces',
                _surfaces.isNotEmpty ? _surfaces.join(', ') : null,
              ),
              _buildInfoTile('Maximum inclination', _maxIncline),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightedStats() {
<<<<<<< HEAD
    final String distanceStr = TrailDetailsScreenHelper.getFormattedDistance(_relationTags?['distance'], _calculatedMeters);
    final String durationStr = TrailDetailsScreenHelper.formatDuration(_durationMinutes);
    final String ascentStr = TrailDetailsScreenHelper.getFormattedAscent(_relationTags?['ascent'], _estimatedAscent);

    _difficulty = _updateDifficulty();
=======
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

    String duration =
        _relationTags?['duration'] ??
        _relationTags?['time'] ??
        _estimatedDuration ??
        'N/D';
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
      } else if (!duration.toLowerCase().contains('h') &&
          !duration.toLowerCase().contains('m')) {
        duration = '$duration h';
      }
    }

    final String ascent = _relationTags?['ascent'] ?? _estimatedAscent ?? 'N/D';
    String ascentStr = 'N/D';
    if (ascent != 'N/D') {
      ascentStr = '+$ascent m';
    }
>>>>>>> 52ad0c6 (Added start button and implemented local trail)

    bool isFerrata = false;
    final caiScale = _relationTags?['cai_scale']?.toString().toUpperCase() ?? '';
    final hasViaFerrata = _relationTags?.containsKey('via_ferrata_scale') ?? false;

    if (caiScale.contains('EEA') || hasViaFerrata) {
      isFerrata = true;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: MediaQuery.textScalerOf(context).scale(120.0),
        children: [
<<<<<<< HEAD
          _buildStatCard(Icons.route, 'Distance', value: distanceStr),
          _buildStatCard(Icons.timer_outlined, 'Duration', value: durationStr),
          _buildStatCard(Icons.hiking, 'Difficulty', valueWidget: _buildDifficultyIcons(_difficulty)),
          _buildStatCard(Icons.height, 'Ascent', valueWidget: _buildAscentAndFerrata(ascentStr, isFerrata)),
=======
          _buildStatCard(Icons.route, 'Distance', value: distance),
          _buildStatCard(Icons.timer_outlined, 'Duration', value: duration),
          _buildStatCard(
            Icons.hiking,
            'Difficulty',
            valueWidget: _buildDifficultyIcons(_difficulty),
          ),
          _buildStatCard(Icons.height, 'Ascent', value: ascentStr),
>>>>>>> 52ad0c6 (Added start button and implemented local trail)
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String title, {
    String? value,
    Widget? valueWidget,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.secondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1,
        ),
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
<<<<<<< HEAD
                    title, 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.8)),
                    maxLines: 1,
=======
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.shadow.withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
>>>>>>> 52ad0c6 (Added start button and implemented local trail)
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (valueWidget != null)
                    valueWidget
                  else if (value != null)
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildWeatherBox() {
    if (_isLoadingWeather) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_weatherForecast == null || _weatherForecast!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(left: 16.0, bottom: 24.0),
        child: Text(
          'Weather data not available.',
          style: TextStyle(color: AppColors.errorText, fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
          child: Text(
            'Weather Forecast',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.8),
            ),
          ),
        ),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(180),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _weatherForecast!.length,
            separatorBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: VerticalDivider(
                  color: Theme.of(context).colorScheme.primary,
                  thickness: 1,
                  width: 1,
                ),
              );
            },
            itemBuilder: (context, index) {
              final day = _weatherForecast![index];

              String desc = day['desc'].toString();
              if (desc.isNotEmpty) {
                desc = desc[0].toUpperCase() + desc.substring(1);
              }

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day['date'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Lottie.asset(
                      TrailDetailsScreenHelper.getLottieAsset(day['code']),
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) =>
                          const Icon(Icons.cloud_outlined, size: 30),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${day['temp_max'].round()}° / ${day['temp_min'].round()}°',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      desc,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildElevationChart() {
    if (_isLoadingElevations) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_elevations == null || _elevations!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(left: 16.0, bottom: 24.0),
        child: Text(
          'Elevation profile not available.',
          style: TextStyle(color: AppColors.errorText, fontSize: 16),
        ),
      );
    }

    List<FlSpot> spots = [];
    double minElev = _elevations!.first;
    double maxElev = _elevations!.first;
    double maxDistKm = _distances!.last / 1000;

    for (int i = 0; i < _elevations!.length; i++) {
      double el = _elevations![i];
      double distKm = _distances![i] / 1000;
      spots.add(FlSpot(distKm, el));
      if (el < minElev) minElev = el;
      if (el > maxElev) maxElev = el;
    }

    double chartMinY = (minElev - 20).clamp(0, double.infinity);
    double chartMaxY = maxElev + 20;

    double totalYRange = chartMaxY - chartMinY;
    double yInterval = (totalYRange / 4).roundToDouble();
    if (yInterval < 10) yInterval = 10;

    double baseInterval;
    if (maxDistKm <= 5.0) {
      baseInterval = 0.5;
    } else if (maxDistKm <= 10.0) {
      baseInterval = 1.0;
    } else if (maxDistKm <= 100.0) {
      baseInterval = 10.0;
    } else if (maxDistKm <= 200.0) {
<<<<<<< HEAD
      baseInterval = 20.0; 
=======
      xInterval = 20.0;
>>>>>>> 52ad0c6 (Added start button and implemented local trail)
    } else {
      baseInterval = 50.0;
    }

    double currentTextScale = MediaQuery.textScalerOf(context).scale(1.0);
    double xInterval = (baseInterval * currentTextScale).ceilToDouble();

    return SizedBox(
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
            child: Text(
              'Elevation Profile',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.8),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxDistKm,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (LineBarSpot touchedSpot) {
                        return Theme.of(context).colorScheme.secondary;
                      },
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          return LineTooltipItem(
                            '${touchedSpot.y.toInt()} m',
                            TextStyle(
                              color: Theme.of(context).colorScheme.shadow,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: MediaQuery.textScalerOf(context).scale(55),
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${value.toInt()}m',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: MediaQuery.textScalerOf(context).scale(35),
                        interval: xInterval,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max ||
                              value == meta.min ||
                              value > maxDistKm) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${value.toInt()} km',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: chartMinY,
                  maxY: chartMaxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      preventCurveOverShooting: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                _buildLinkedText(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedText(String text) {
    final RegExp urlRegex = RegExp(
      r'((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?',
    );
    final matches = urlRegex.allMatches(text);

    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;
    final TextStyle baseStyle = TextStyle(fontSize: 14);

    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final String url = match.group(0)!;
      final String fullUrl = url.startsWith('http') ? url : 'https://$url';

      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.blue,
            decoration: TextDecoration.underline,
            decorationColor: Colors.blue,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.parse(fullUrl);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open the link.')),
                  );
                }
              }
            },
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans), style: baseStyle);
  }

  Widget _buildFloatingButtons() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 50.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddActivityPage(
                        activity: Activity(
                          id: "",
                          name: widget.trail['name'],
                          status: ActivityStatus.planned,
                          date: DateTime.now(),
                          trailName: widget.trail['name'],
                          trailId: widget.trail['id']?.toString() ?? '',
                          trailPath: _trailPath,
                          distanceKm: _distanceKm,
                          durationMinutes: _activityDurationMinutes,
                          difficulty: difficulty,
<<<<<<< HEAD
                          xpEarned: TrailDetailsScreenHelper.calculateXp(difficulty)
=======
                          xpEarned: _calculateXpFromDifficulty(difficulty),
>>>>>>> 52ad0c6 (Added start button and implemented local trail)
                        ),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.calendar_month),
                label: const Text(
                  'Plan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NavigatorScreen(
                        trail: widget.trail,
                        activity: Activity(
                          id: "",
                          name: widget.trail['name'],
                          status: ActivityStatus.planned,
<<<<<<< HEAD
                          durationMinutes: _durationMinutes,
=======
                          trailName: widget.trail['name'],
                          trailId: widget.trail['id']?.toString() ?? '',
                          trailPath: _trailPath,
                          distanceKm: _distanceKm,
                          durationMinutes: _activityDurationMinutes,
>>>>>>> 52ad0c6 (Added start button and implemented local trail)
                          date: DateTime.now(),
                          difficulty: difficulty,
                          xpEarned: TrailDetailsScreenHelper.calculateXp(difficulty),
                        ),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.navigation),
                label: const Text(
                  'Start',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyIcons(int level) {
    if (level == 0) {
      return const Text(
        'N/D',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(right: 1.0, top: 2.0),
              child: Icon(
                index < level ? Icons.landscape : Icons.landscape_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            );
          }),
        ),
        const SizedBox(height: 3.0),
        Text(
          level == 1
              ? '(Beginner)'
              : level == 2
              ? '(Intermediate)'
              : '(Expert)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

<<<<<<< HEAD
  Widget _buildAscentAndFerrata(String ascentStr, bool isFerrata) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ascentStr, 
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), 
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (isFerrata)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3.0),
              Text(
                '(Ferrata)',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
      ],
    );
  }
}
=======
  int _fromStringToMinutesInt(String? duration) {
    if (duration == null) return 0;

    final match = RegExp(
      r'^(\d+)\s*h\s*(\d+)\s*m(?:\s*\(estimated\))?$',
    ).firstMatch(duration.trim());

    if (match == null) return 0;

    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    return (hours * 60) + minutes;
  }

  int get _activityDurationMinutes {
    if (_durationMinutes > 0) return _durationMinutes;

    final duration =
        _relationTags?['duration'] ??
        _relationTags?['time'] ??
        _estimatedDuration;
    return _fromStringToMinutesInt(duration?.toString());
  }

  List<List<TrailPoint>> get _trailPath {
    final subTrails = widget.trail['subTrails'];
    if (subTrails is! List) return const [];

    return subTrails
        .map<List<TrailPoint>>((segment) {
          if (segment is! List) return const [];

          return segment
              .whereType<LatLng>()
              .map(
                (point) =>
                    TrailPoint(lat: point.latitude, lng: point.longitude),
              )
              .toList(growable: false);
        })
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
  }

  double _calculateXpFromDifficulty(ActivityDifficulty difficulty) {
    switch (difficulty) {
      case ActivityDifficulty.easy:
        return 50;
      case ActivityDifficulty.moderate:
        return 100;
      case ActivityDifficulty.hard:
        return 200;
    }
  }
}
>>>>>>> 52ad0c6 (Added start button and implemented local trail)
