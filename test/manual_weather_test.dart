import 'package:banana_weather/services/weather_service.dart';

void main() async {
  final service = WeatherService();
  print('Testing WeatherService with Gemini...');

  try {
    final weather = await service.getWeatherByCity('San Francisco, CA');
    print('--------------------------------------------------');
    print('City: ${weather.cityName}');
    print('Temp: ${weather.temperature}');
    print('Condition: ${weather.mainCondition}');
    print('Description: ${weather.description}');
    print('Landmarks: ${weather.landmarks}');
    print('Image Base64 Length: ${weather.imageBase64?.length ?? 0}');
    print('--------------------------------------------------');

    if (weather.landmarks.isNotEmpty && weather.temperature != 0) {
      print('TEST PASSED: Data fetched successfully.');
    } else {
      print('TEST FAILED: Missing data.');
    }
  } catch (e) {
    print('TEST FAILED: Exception: $e');
  }
}
