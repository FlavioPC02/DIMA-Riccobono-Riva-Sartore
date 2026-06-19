import 'dart:convert';
import 'package:application/core/models/weather_data.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class WeatherService {
  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  Future<WeatherData> fetchWeather(DateTime date, [double? lat, double? lon]) async {
    
    final dateStr = _fmtDate(date);

    double latitude;
    double longitude;
    //if lat and lot are null used current position
    if (lat == null || lon == null) {
      final position = await _getPosition();
      latitude = position.latitude;
      longitude = position.longitude;
    } else {
      latitude = lat;
      longitude = lon;
    }

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,'
      'precipitation_probability_max,wind_speed_10m_max'
      '&hourly=temperature_2m,weather_code,precipitation_probability'
      '&timezone=auto'
      '&forecast_days=14',
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Weather unavailable (HTTP ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;
    final dailyTimes = daily['time'] as List;
    final dayIndex = dailyTimes.indexOf(dateStr);

    if (dayIndex == -1) throw Exception('No forecast available for this date');

    final hourlyData = json['hourly'] as Map<String, dynamic>;
    final hourlyTimes = hourlyData['time'] as List;
    final hourlyCodes = hourlyData['weather_code'] as List;
    final hourlyTemps = hourlyData['temperature_2m'] as List;
    final hourlyPrecipitation = hourlyData['precipitation_probability'] as List;

    final hourly = <WeatherHourEntry>[];
    for (var i = 0; i < hourlyTimes.length; i++) {
      final timestamp = hourlyTimes[i] as String;
      if (!timestamp.startsWith(dateStr)) continue;

      hourly.add(
        WeatherHourEntry(
          time: DateTime.parse(timestamp),
          weatherCode: _mapWmoToIconCode(hourlyCodes[i] as int),
          temp: (hourlyTemps[i] as num).toDouble(),
          precipitationProbability: (hourlyPrecipitation[i] as num).round(),
        ),
      );
    }

    return WeatherData(
      weatherCode: _mapWmoToIconCode(daily['weather_code'][dayIndex] as int),
      maxTemp: (daily['temperature_2m_max'][dayIndex] as num).toDouble(),
      minTemp: (daily['temperature_2m_min'][dayIndex] as num).toDouble(),
      precipitationProbability:
          (daily['precipitation_probability_max'][dayIndex] as num).round(),
      windSpeed: (daily['wind_speed_10m_max'][dayIndex] as num).toDouble(),
      hourly: hourly,
    );
  }

  Future<List<Map<String, dynamic>>> fetchMultipleDaysForecast(
    double lat,
    double lon,
  ) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lon'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min'
      '&timezone=auto'
      '&forecast_days=14',
    );

    final response = await _client.get(uri);

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

      int mappedCode = _mapWmoToIconCode(wmoCode);
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
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
  }

  // Maps Open-Meteo WMO codes to the icon buckets used by the app.
  int _mapWmoToIconCode(int wmoCode) {
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
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 77:
        return 'Snow grains';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm & hail';
      default:
        return 'Unknown';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
