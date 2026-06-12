import 'package:flutter_test/flutter_test.dart';
import 'package:application/core/models/weather_data.dart';

void main() {
  group('WeatherData', () {
    test('can construct WeatherData with hourly entries', () {
      final hourly = [
        WeatherHourEntry(
          time: DateTime.utc(2024, 1, 1, 12),
          weatherCode: 1,
          temp: 20.0,
          precipitationProbability: 10,
        ),
      ];

      final weatherData = WeatherData(
        weatherCode: 2,
        maxTemp: 25.1,
        minTemp: 15.3,
        precipitationProbability: 30,
        windSpeed: 5.5,
        hourly: hourly,
      );

      expect(weatherData.weatherCode, 2);
      expect(weatherData.maxTemp, 25.1);
      expect(weatherData.minTemp, 15.3);
      expect(weatherData.precipitationProbability, 30);
      expect(weatherData.windSpeed, 5.5);
      expect(weatherData.hourly, hourly);
    });
  });
}
