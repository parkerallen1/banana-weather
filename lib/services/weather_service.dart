import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../api_keys.dart';
import '../models/weather_model.dart';
import 'log_service.dart';

class WeatherService {
  // 0 = Gemini, 1 = OpenWeatherMap
  static const int useWeatherApi = 1;
  static const String _openWeatherBaseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  Future<Weather> getWeather(double lat, double lon) async {
    if (useWeatherApi == 1) {
      LogService.instance.log(
        'WeatherService: Fetching weather for lat=$lat, lon=$lon via OpenWeatherMap',
      );
      final url =
          '$_openWeatherBaseUrl?lat=$lat&lon=$lon&appid=$openWeatherApiKey&units=imperial';
      try {
        return await _getOpenWeatherMapData(url);
      } catch (e) {
        LogService.instance.log(
          'WeatherService: Error fetching weather via OpenWeatherMap: $e',
        );
        return _getMockWeather('Unknown');
      }
    } else {
      LogService.instance.log(
        'WeatherService: Fetching weather for lat=$lat, lon=$lon via Gemini',
      );
      return _getGeminiWeatherData('coordinates: $lat, $lon');
    }
  }

  Future<Weather> getWeatherByCity(String cityName) async {
    if (useWeatherApi == 1) {
      LogService.instance.log(
        'WeatherService: Fetching weather for city=$cityName via OpenWeatherMap',
      );
      final url =
          '$_openWeatherBaseUrl?q=$cityName&appid=$openWeatherApiKey&units=imperial';
      try {
        return await _getOpenWeatherMapData(url);
      } catch (e) {
        LogService.instance.log(
          'WeatherService: OpenWeatherMap failed for $cityName, falling back to Gemini for fantasy check: $e',
        );
        return _getGeminiWeatherData(cityName);
      }
    } else {
      LogService.instance.log(
        'WeatherService: Fetching weather for city=$cityName via Gemini',
      );
      return _getGeminiWeatherData(cityName);
    }
  }

  Future<Weather> _getOpenWeatherMapData(String url) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return Weather.fromJson(jsonResponse);
    } else {
      LogService.instance.log(
        'WeatherService: OpenWeatherMap Failed: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to load weather data');
    }
  }

  Future<Weather> _getGeminiWeatherData(String locationQuery) async {
    if (geminiApiKey == 'YOUR_GEMINI_KEY_HERE' || geminiApiKey.isEmpty) {
      LogService.instance.log(
        'WeatherService: Gemini key missing, returning mock',
      );
      return _getMockWeather(locationQuery);
    }

    try {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$geminiApiKey';

      final prompt =
          '''
      Find the current weather for $locationQuery.
      If the location is a fictional or fantasy place (e.g. Mordor, Atlantis, The Moon, Hogwarts), generate plausible fantasy weather and landmarks that fit the lore.
      If the location is real, provide real weather.
      Also find 3 distinct, real (or lore-accurate), and iconic landmarks for this specific location.
      Return ONLY a JSON object with the following structure:
      {
        "cityName": "City Name, State/Province",
        "lat": 0.0,
        "lon": 0.0,
        "temperature": 75.0,
        "condition": "Sunny",
        "description": "Clear sky",
        "landmarks": ["Landmark 1", "Landmark 2", "Landmark 3"],
        "backgroundColor": "#RRGGBB",
        "fontColor": "#RRGGBB"
      }
      Temperature should be in Fahrenheit.
      Condition should be one of: Clear, Clouds, Rain, Snow, Thunderstorm, Drizzle, Mist, Fog, Haze, Smoke, Dust, Sand, Ash, Squall, Tornado.
      For fantasy locations, choose a condition that fits (e.g. Ash for Mordor, Mist for Atlantis).
      "backgroundColor" should be a hex code for a solid background color that fits the location and weather (e.g. dark grey for Mordor, bright blue for sunny beach).
      "fontColor" should be a hex code for a font color that contrasts HIGHLY with the backgroundColor (e.g. white for dark background, black for light background).
      ''';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'tools': [
          {'googleSearch': {}},
        ],
      };

      LogService.instance.log(
        'WeatherService: Calling Gemini API for weather...',
      );
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      LogService.instance.log(
        'WeatherService: Gemini Response Code: ${response.statusCode}',
      );
      LogService.instance.log(
        'WeatherService: Gemini Response Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['candidates'] != null &&
            jsonResponse['candidates'].isNotEmpty) {
          final candidate = jsonResponse['candidates'][0];
          final parts = candidate['content']['parts'] as List;
          final textPart = parts.firstWhere(
            (p) => p.containsKey('text'),
            orElse: () => null,
          );

          if (textPart != null) {
            String text = textPart['text'];
            // Clean up markdown code blocks if present
            text = text.replaceAll('```json', '').replaceAll('```', '').trim();

            final data = jsonDecode(text);

            final cityName = data['cityName'] ?? locationQuery;
            final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
            final lon = (data['lon'] as num?)?.toDouble() ?? 0.0;
            final temp = (data['temperature'] as num).toDouble();
            final condition = data['condition'] ?? 'Clear';
            final description = data['description'] ?? 'Unknown';
            final landmarks = List<String>.from(data['landmarks'] ?? []);
            final backgroundColor = data['backgroundColor'];
            final fontColor = data['fontColor'];

            // Map condition to icon code (simplified)
            String iconCode = '01d';
            final lowerCondition = condition.toLowerCase();
            if (lowerCondition.contains('cloud')) {
              iconCode = '03d';
            } else if (lowerCondition.contains('rain') ||
                lowerCondition.contains('drizzle')) {
              iconCode = '09d';
            } else if (lowerCondition.contains('snow')) {
              iconCode = '13d';
            } else if (lowerCondition.contains('thunder')) {
              iconCode = '11d';
            } else if (lowerCondition.contains('fog') ||
                lowerCondition.contains('mist') ||
                lowerCondition.contains('haze')) {
              iconCode = '50d';
            } else if (lowerCondition.contains('smoke') ||
                lowerCondition.contains('dust') ||
                lowerCondition.contains('sand') ||
                lowerCondition.contains('ash')) {
              iconCode = '50d';
            } else if (lowerCondition.contains('squall') ||
                lowerCondition.contains('tornado')) {
              iconCode = '50d';
            }

            return Weather(
              cityName: cityName,
              temperature: temp,
              mainCondition: condition,
              description: description,
              iconCode: iconCode,
              date: DateTime.now(),
              lat: lat,
              lon: lon,
              landmarks: landmarks,
              imageBase64: null,
              fontColor: fontColor,
              backgroundColor: backgroundColor,
            );
          }
        }
      }
    } catch (e) {
      LogService.instance.log(
        'WeatherService: Error fetching weather via Gemini: $e',
      );
    }

    return _getMockWeather(locationQuery);
  }

  Future<String?> generateImage(Weather weather) async {
    return _generateImage(
      weather.cityName,
      weather.mainCondition,
      weather.temperature,
      weather.landmarks,
      weather.backgroundColor,
    );
  }

  Future<String?> _generateImage(
    String cityName,
    String condition,
    double temp,
    List<String> landmarks,
    String? backgroundColor,
  ) async {
    // 1. Try Gemini 2.5 Flash Image (User requested replacement for 3.0 Pro and Imagen)
    try {
      final image = await _generateImageWithGeminiFlash(
        cityName,
        condition,
        temp,
        landmarks,
        backgroundColor,
      );
      if (image != null) {
        return image;
      }
    } catch (e) {
      LogService.instance.log(
        'WeatherService: Gemini 2.5 Flash Image failed: $e',
      );
    }

    // Commented out previous logic as requested
    /*
    // 1. Try Gemini 3 Pro first
    try {
      final geminiImage = await _generateImageWithGemini(
        cityName,
        condition,
        temp,
        landmarks,
        backgroundColor,
      );
      if (geminiImage != null) {
        return geminiImage;
      }
    } catch (e) {
      LogService.instance.log('WeatherService: Gemini 3 Pro failed: $e');
      // Continue to fallback
    }

    // 2. Fallback to Imagen 4.0 Fast
    LogService.instance.log('WeatherService: Fallback to Imagen 4.0 Fast...');
    return _generateImageWithImagen(
      cityName,
      condition,
      temp,
      landmarks,
      backgroundColor,
    );
    */
    return null;
  }

  Future<String?> _generateImageWithGeminiFlash(
    String cityName,
    String condition,
    double temp,
    List<String> landmarks,
    String? backgroundColor,
  ) async {
    if (geminiApiKey == 'YOUR_GEMINI_KEY_HERE' || geminiApiKey.isEmpty) {
      return null;
    }

    LogService.instance.log(
      'WeatherService: Attempting image generation via Gemini 2.5 Flash Image for $cityName...',
    );

    String landmarkText = "iconic landmarks";
    if (landmarks.isNotEmpty) {
      landmarkText = "specific landmarks including ${landmarks.join(', ')}";
    }

    // Construct the prompt as a JSON object (Same format as 3 Pro)
    final promptJson = {
      "subject":
          "A clear, 45° top-down isometric miniature 3D scene of $cityName set on a distinct, isolated square base. The city is a compact cluster of $landmarkText restricted to this square plot.",
      "style":
          "Soft, refined textures with realistic PBR materials and gentle, lifelike lighting. The look is a high-quality miniature dioramas, not a flat cartoon.",
      "composition": {
        "aspect_ratio": "9:16",
        "background":
            "A solid color: ${backgroundColor ?? 'soft pastel color'}. Uniform and clean. No complex full-scene scenery behind the diorama to ensure text readability.",
        "layout":
            "The square city plot is centered in the lower half. IMPORTANT: Leave significant negative space on the Left and Right sides of the city. The city must NOT touch the edges of the image. It should stay in the middle 50% of the image",
      },
      "weather_integration":
          "Reflect current weather ($condition) both on the buildings and in the air immediately above the plot. If the weather calls for it, include floating miniature 3D clouds, falling rain, drifting snow, or sun rays hovering strictly over the city base. Keep these elements contained to the diorama area; do not fill the entire upper background.",
    };

    final prompt = jsonEncode(promptJson);

    // Updated URL for Gemini 2.5 Flash Image
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=$geminiApiKey';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        // Assuming 2.5 Flash Image supports the same generationConfig
        'generationConfig': {
          'imageConfig': {'aspectRatio': '9:16'},
        },
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['candidates'] != null &&
          json['candidates'].isNotEmpty &&
          json['candidates'][0]['content'] != null &&
          json['candidates'][0]['content']['parts'] != null) {
        final parts = json['candidates'][0]['content']['parts'] as List;
        for (var part in parts) {
          if (part['inlineData'] != null) {
            LogService.instance.log(
              'WeatherService: Gemini 2.5 Flash Image generated successfully!',
            );
            return part['inlineData']['data']; // Base64 string
          }
        }
        LogService.instance.log(
          'WeatherService: Gemini 2.5 Flash Image response missing inlineData in parts. Full response: ${response.body}',
        );
      } else {
        LogService.instance.log(
          'WeatherService: Gemini 2.5 Flash Image response missing candidates or content. Full response: ${response.body}',
        );
      }
    } else {
      LogService.instance.log(
        'WeatherService: Gemini 2.5 Flash Image Failed: ${response.body}',
      );
    }
    return null;
  }

  Future<String?> _generateImageWithGemini(
    String cityName,
    String condition,
    double temp,
    List<String> landmarks,
    String? backgroundColor,
  ) async {
    if (geminiApiKey == 'YOUR_GEMINI_KEY_HERE' || geminiApiKey.isEmpty) {
      return null;
    }

    LogService.instance.log(
      'WeatherService: Attempting image generation via Gemini 3 Pro for $cityName...',
    );

    String landmarkText = "iconic landmarks";
    if (landmarks.isNotEmpty) {
      landmarkText = "specific landmarks including ${landmarks.join(', ')}";
    }

    // Construct the prompt as a JSON object (Gemini 3 Pro format)
    final promptJson = {
      "subject":
          "A clear, 45° top-down isometric miniature 3D scene of $cityName set on a distinct, isolated square base. The city is a compact cluster of $landmarkText restricted to this square plot.",
      "style":
          "Soft, refined textures with realistic PBR materials and gentle, lifelike lighting. The look is a high-quality miniature dioramas, not a flat cartoon.",
      "composition": {
        "aspect_ratio": "9:16",
        "background":
            "A solid color: ${backgroundColor ?? 'soft pastel color'}. Uniform and clean. No complex full-scene scenery behind the diorama to ensure text readability.",
        "layout":
            "The square city plot is centered in the lower half. IMPORTANT: Leave significant negative space on the Left and Right sides of the city. The city must NOT touch the edges of the image. It should stay in the middle 50% of the image",
      },
      "weather_integration":
          "Reflect current weather ($condition) both on the buildings and in the air immediately above the plot. If the weather calls for it, include floating miniature 3D clouds, falling rain, drifting snow, or sun rays hovering strictly over the city base. Keep these elements contained to the diorama area; do not fill the entire upper background.",
    };

    final prompt = jsonEncode(promptJson);

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=$geminiApiKey';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'imageConfig': {'aspectRatio': '9:16'},
        },
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['candidates'] != null &&
          json['candidates'].isNotEmpty &&
          json['candidates'][0]['content'] != null &&
          json['candidates'][0]['content']['parts'] != null) {
        final parts = json['candidates'][0]['content']['parts'] as List;
        for (var part in parts) {
          if (part['inlineData'] != null) {
            LogService.instance.log(
              'WeatherService: Gemini 3 Pro Image generated successfully!',
            );
            return part['inlineData']['data']; // Base64 string
          }
        }
        LogService.instance.log(
          'WeatherService: Gemini 3 Pro response missing inlineData in parts. Full response: ${response.body}',
        );
      } else {
        LogService.instance.log(
          'WeatherService: Gemini 3 Pro response missing candidates or content. Full response: ${response.body}',
        );
      }
    } else if (response.statusCode == 503) {
      LogService.instance.log('WeatherService: Gemini 3 Pro Overloaded (503)');
      throw Exception('Gemini 3 Pro Overloaded');
    } else {
      LogService.instance.log(
        'WeatherService: Gemini 3 Pro Failed: ${response.body}',
      );
    }
    return null;
  }

  Future<String?> _generateImageWithImagen(
    String cityName,
    String condition,
    double temp,
    List<String> landmarks,
    String? backgroundColor,
  ) async {
    if (geminiApiKey == 'YOUR_GEMINI_KEY_HERE' || geminiApiKey.isEmpty) {
      return null;
    }

    try {
      LogService.instance.log(
        'WeatherService: Generating image via Imagen 4.0 Fast for $cityName with landmarks: $landmarks...',
      );

      String landmarkText = "iconic landmarks";
      if (landmarks.isNotEmpty) {
        landmarkText = "specific landmarks including ${landmarks.join(', ')}";
      }

      // Construct a rich descriptive prompt for Imagen
      final prompt =
          "A clear, 45° top-down isometric miniature 3D scene of $cityName set on a distinct, isolated square base. "
          "The city is a compact cluster of $landmarkText restricted to this square plot. "
          "Style: Soft, refined textures with realistic PBR materials and gentle, lifelike lighting. "
          "The look is a high-quality miniature dioramas, not a flat cartoon. "
          "Composition: The square city plot is centered in the lower half. "
          "IMPORTANT: Leave significant negative space on the Left and Right sides of the city. "
          "The city must NOT touch the edges of the image. It should stay in the middle 50% of the image. "
          "Weather: Reflect current weather ($condition) both on the buildings and in the air immediately above the plot. "
          "If the weather calls for it, include floating miniature 3D clouds, falling rain, drifting snow, or sun rays hovering strictly over the city base. "
          "Keep these elements contained to the diorama area; do not fill the entire upper background. "
          "Background: A solid color: ${backgroundColor ?? 'soft pastel color'}. Uniform and clean. No complex full-scene scenery behind the diorama to ensure text readability.";

      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-fast-generate-001:predict?key=$geminiApiKey';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'instances': [
            {'prompt': prompt},
          ],
          'parameters': {'sampleCount': 1, 'aspectRatio': '9:16'},
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['predictions'] != null && json['predictions'].isNotEmpty) {
          final prediction = json['predictions'][0];
          if (prediction['bytesBase64Encoded'] != null) {
            LogService.instance.log(
              'WeatherService: Imagen 4.0 Fast Image generated successfully!',
            );
            return prediction['bytesBase64Encoded'];
          } else {
            LogService.instance.log(
              'WeatherService: Imagen 4.0 Fast response missing bytesBase64Encoded. Full response: ${response.body}',
            );
          }
        } else {
          LogService.instance.log(
            'WeatherService: Imagen 4.0 Fast response missing predictions. Full response: ${response.body}',
          );
        }
      } else {
        LogService.instance.log(
          'WeatherService: Imagen 4.0 Fast Failed: ${response.body}',
        );
      }
    } catch (e) {
      LogService.instance.log(
        'WeatherService: Error generating image with Imagen: $e',
      );
    }
    return null;
  }

  Future<Weather> _getMockWeather(String cityName) async {
    LogService.instance.log(
      'WeatherService: Generating mock weather for $cityName',
    );
    final random = Random();
    final isHot = random.nextBool();
    final temp = isHot ? 25 + random.nextInt(15) : -5 + random.nextInt(20);
    final conditions = [
      {
        'main': 'Clear',
        'desc': 'Sunny with a chance of dragons',
        'icon': '01d',
      },
      {'main': 'Clouds', 'desc': 'Gloomy shadows', 'icon': '03d'},
      {'main': 'Rain', 'desc': 'Tears of the ancients', 'icon': '09d'},
      {'main': 'Snow', 'desc': 'Nuclear winter', 'icon': '13d'},
      {'main': 'Thunderstorm', 'desc': 'Zeus is angry', 'icon': '11d'},
    ];
    final condition = conditions[random.nextInt(conditions.length)];

    // Mock weather does NOT generate an image automatically anymore
    // to match the new flow.

    return Weather(
      cityName: cityName,
      temperature: temp.toDouble(),
      mainCondition: condition['main'] as String,
      description: condition['desc'] as String,
      iconCode: condition['icon'] as String,
      date: DateTime.now(),
      lat: 40.7128 + (random.nextDouble() - 0.5), // Approx NYC lat
      lon: -74.0060 + (random.nextDouble() - 0.5), // Approx NYC lon
      landmarks: [],
      imageBase64: null,
    );
  }
}
