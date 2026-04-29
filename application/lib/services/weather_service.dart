import 'dart:convert';
import 'package:application/core/models/weather_data.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  static const _baseUrl = 'https://api.openweathermap.org/data/2.5/forecast';

  Future<WeatherData> fetchWeather(DateTime date) async {
    final apiKey = dotenv.env['OPENWEATHER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenWeatherMap API key not configured');
    }

    final position = await _getPosition();
    final dateStr = _fmtDate(date);

    final uri = Uri.parse(
      '$_baseUrl'
      '?lat=${position.latitude}'
      '&lon=${position.longitude}'
      '&appid=$apiKey'
      '&units=metric',
    );

    final response = await http.get(uri);
    if (response.statusCode == 401) {
      throw Exception(
        'Invalid API key — it may take up to 2 hours to activate after registration',
      );
    }
    if (response.statusCode != 200) {
      throw Exception('Weather unavailable (HTTP ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = json['list'] as List;

    // All entries for the requested date
    final entries = list.where((e) {
      final txt = e['dt_txt'] as String;
      return txt.startsWith(dateStr);
    }).toList();

    if (entries.isEmpty) throw Exception('No forecast available for this date');

    // Build hourly entries
    final hourly = entries.map((e) {
      final dtTxt = e['dt_txt'] as String; // "2024-05-10 12:00:00"
      final parts = dtTxt.split(' ');
      final timeParts = parts[1].split(':');
      final time = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
      return WeatherHourEntry(
        time: time,
        weatherCode:
            (e['weather'] as List).first['id'] as int,
        temp: ((e['main'] as Map)['temp'] as num).toDouble(),
        precipitationProbability:
            (((e['pop'] as num?) ?? 0) * 100).round(),
      );
    }).toList();

    // Aggregate daily summary
    double maxTemp = double.negativeInfinity;
    double minTemp = double.infinity;
    double maxPop = 0;
    double maxWind = 0;
    int weatherCode =
        (entries.first['weather'] as List).first['id'] as int;

    for (final e in entries) {
      final main = e['main'] as Map<String, dynamic>;
      final tMax = (main['temp_max'] as num).toDouble();
      final tMin = (main['temp_min'] as num).toDouble();
      final pop = ((e['pop'] as num?) ?? 0).toDouble();
      final wind = ((e['wind']?['speed'] as num?) ?? 0).toDouble();
      if (tMax > maxTemp) maxTemp = tMax;
      if (tMin < minTemp) minTemp = tMin;
      if (pop > maxPop) maxPop = pop;
      if (wind > maxWind) maxWind = wind;
      if ((e['dt_txt'] as String).contains('12:00:00')) {
        weatherCode = (e['weather'] as List).first['id'] as int;
      }
    }

    return WeatherData(
      weatherCode: weatherCode,
      maxTemp: maxTemp,
      minTemp: minTemp,
      precipitationProbability: (maxPop * 100).round(),
      windSpeed: maxWind * 3.6,
      hourly: hourly,
    );
  }

  Future<Position> _getPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
