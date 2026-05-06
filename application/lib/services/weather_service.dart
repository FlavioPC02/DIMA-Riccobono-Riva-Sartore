import 'dart:convert';
import 'package:application/core/models/weather_data.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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

  Future<List<Map<String, dynamic>>> fetchMultipleDaysForecast(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lon'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min'
      '&timezone=auto'
      '&forecast_days=14' 
    );

    final response = await http.get(uri);
    
    if (response.statusCode != 200) {
      throw Exception('Weather unavailable (HTTP ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    final times = daily['time'] as List;
    final codes = daily['weather_code'] as List;
    final tempsMax = daily['temperature_2m_max'] as List;
    final tempsMin = daily['temperature_2m_min'] as List;

    List<Map<String, dynamic>> forecastList = [];

    for (int i = 0; i < times.length; i++) {
      DateTime date = DateTime.parse(times[i]);
      String dateStr = DateFormat('EEE, MMM d').format(date);
      
      int wmoCode = codes[i] as int;
      
      int mappedCode = _mapWmoToOwm(wmoCode);
      String desc = _getWmoDescription(wmoCode);

      forecastList.add({
        'date': dateStr,
        'temp_min': (tempsMin[i] as num).toDouble(),
        'temp_max': (tempsMax[i] as num).toDouble(),
        'desc': desc,
        'code': mappedCode,
      });
    }

    return forecastList;
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

  // helper mtehods to map WMO codes to OpenWeatherMap codes and descriptions
  int _mapWmoToOwm(int wmoCode) {
    if (wmoCode == 0) return 800;
    if (wmoCode == 1) return 801;
    if (wmoCode == 2) return 802;
    if (wmoCode == 3) return 804;
    if (wmoCode == 45 || wmoCode == 48) return 700;
    if (wmoCode >= 51 && wmoCode <= 57) return 300;
    if (wmoCode >= 61 && wmoCode <= 67) return 500;
    if (wmoCode >= 71 && wmoCode <= 77) return 600;
    if (wmoCode >= 80 && wmoCode <= 82) return 500;
    if (wmoCode >= 85 && wmoCode <= 86) return 600;
    if (wmoCode >= 95 && wmoCode <= 99) return 200;
    return 800;
  }

  String _getWmoDescription(int wmoCode) {
    switch (wmoCode) {
      case 0: return 'Clear sky';
      case 1: return 'Mainly clear';
      case 2: return 'Partly cloudy';
      case 3: return 'Overcast';
      case 45: case 48: return 'Fog';
      case 51: case 53: case 55: return 'Drizzle';
      case 56: case 57: return 'Freezing drizzle';
      case 61: case 63: case 65: return 'Rain';
      case 66: case 67: return 'Freezing rain';
      case 71: case 73: case 75: return 'Snow';
      case 77: return 'Snow grains';
      case 80: case 81: case 82: return 'Rain showers';
      case 85: case 86: return 'Snow showers';
      case 95: return 'Thunderstorm';
      case 96: case 99: return 'Thunderstorm & hail';
      default: return 'Unknown';
    }
  }

  String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}