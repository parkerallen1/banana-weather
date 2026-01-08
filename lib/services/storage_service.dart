import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import '../models/weather_model.dart';

import 'log_service.dart';

class StorageService {
  static const String _locationsKey = 'saved_locations';
  static const String _weatherCacheKey = 'weather_cache';

  Future<void> saveLocations(List<Location> locations) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      locations.map((loc) => loc.toJson()).toList(),
    );
    await prefs.setString(_locationsKey, encodedData);
  }

  Future<List<Location>> getSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_locationsKey);

    if (encodedData == null) {
      return [];
    }

    final List<dynamic> decodedData = json.decode(encodedData);
    return decodedData.map((json) => Location.fromJson(json)).toList();
  }

  Future<void> saveWeatherCache(Map<int, Weather> cache) async {
    final prefs = await SharedPreferences.getInstance();
    final directory = await getApplicationDocumentsDirectory();

    final Map<int, Weather> updatedCache = {};

    for (var entry in cache.entries) {
      final key = entry.key;
      final weather = entry.value;

      // If we have base64 data but no local path, save it to a file
      if (weather.imageBase64 != null && weather.localImagePath == null) {
        final fileName = 'weather_image_$key.png';
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(base64Decode(weather.imageBase64!));

        updatedCache[key] = Weather(
          cityName: weather.cityName,
          temperature: weather.temperature,
          mainCondition: weather.mainCondition,
          description: weather.description,
          iconCode: weather.iconCode,
          date: weather.date,
          lat: weather.lat,
          lon: weather.lon,
          imagePrompt: weather.imagePrompt,
          imageBase64: weather.imageBase64, // Keep it in memory for now
          localImagePath: fileName, // Save RELATIVE path (filename only)
          landmarks: weather.landmarks,
        );
      } else if (weather.localImagePath != null) {
        // Ensure we are saving the relative path if it was already absolute
        String relativePath = weather.localImagePath!;
        if (relativePath.startsWith(directory.path)) {
          relativePath = relativePath.replaceFirst('${directory.path}/', '');
        }

        updatedCache[key] = weather.copyWith(localImagePath: relativePath);
      } else {
        updatedCache[key] = weather;
      }
    }

    final Map<String, dynamic> encodableCache = updatedCache.map(
      (key, value) => MapEntry(key.toString(), value.toJson()),
    );
    final String encodedData = json.encode(encodableCache);
    await prefs.setString(_weatherCacheKey, encodedData);
  }

  Future<Map<int, Weather>> getSavedWeatherCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_weatherCacheKey);
    final directory = await getApplicationDocumentsDirectory();

    if (encodedData == null) {
      return {};
    }

    try {
      final Map<String, dynamic> decodedData = json.decode(encodedData);
      final Map<int, Weather> cache = {};

      decodedData.forEach((key, value) {
        try {
          final weather = Weather.fromStorage(value);

          // Reconstruct absolute path if a relative path exists
          if (weather.localImagePath != null &&
              !weather.localImagePath!.startsWith('/')) {
            final absolutePath = '${directory.path}/${weather.localImagePath}';
            cache[int.parse(key)] = weather.copyWith(
              localImagePath: absolutePath,
            );
          } else {
            cache[int.parse(key)] = weather;
          }
        } catch (e) {
          LogService.instance.log(
            'StorageService: Error decoding weather item $key: $e. Skipping.',
          );
          // Skip this item but continue loading others
        }
      });

      return cache;
    } catch (e) {
      LogService.instance.log(
        'StorageService: Error decoding weather cache: $e',
      );
      return {};
    }
  }
}
