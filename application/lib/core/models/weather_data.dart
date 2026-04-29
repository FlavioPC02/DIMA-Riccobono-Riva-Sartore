class WeatherHourEntry {
  final DateTime time;
  final int weatherCode;
  final double temp;
  final int precipitationProbability;

  const WeatherHourEntry({
    required this.time,
    required this.weatherCode,
    required this.temp,
    required this.precipitationProbability,
  });
}

class WeatherData {
  final int weatherCode;
  final double maxTemp;
  final double minTemp;
  final int precipitationProbability;
  final double windSpeed;
  final List<WeatherHourEntry> hourly;

  const WeatherData({
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.precipitationProbability,
    required this.windSpeed,
    this.hourly = const [],
  });
}
