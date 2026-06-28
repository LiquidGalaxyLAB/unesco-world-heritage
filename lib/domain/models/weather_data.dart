class WeatherData {
  const WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.windSpeed,
    required this.windDirection,
  });

  final double temperature;
  final double feelsLike;
  final double windSpeed;
  final int windDirection;
}
