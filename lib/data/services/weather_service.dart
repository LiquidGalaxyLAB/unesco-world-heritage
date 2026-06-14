import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/models/weather_data.dart';

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WeatherData?> fetchCurrentWeather(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,wind_speed_10m,wind_direction_10m,apparent_temperature',
      );
      final response = await _client.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        
        if (current != null) {
          return WeatherData(
            temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
            feelsLike: (current['apparent_temperature'] as num?)?.toDouble() ?? 0.0,
            windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
            windDirection: (current['wind_direction_10m'] as num?)?.toInt() ?? 0,
          );
        }
      }
    } catch (_) {
      // Return null on failure
    }
    return null;
  }
}
