import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/weather_model.dart';

class WeatherCard extends StatelessWidget {
  final Weather? weather;
  final bool isLoading;
  final String? loadingMessage;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onRefresh;

  const WeatherCard({
    super.key,
    this.weather,
    this.isLoading = false,
    this.loadingMessage,
    this.errorMessage,
    this.onRetry,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && weather == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            if (loadingMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                loadingMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (weather == null) {
      return const Center(
        child: Text('No Data', style: TextStyle(color: Colors.white)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _getBackgroundColors(weather!.mainCondition),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fullscreen Image Background
          if (weather!.localImagePath != null)
            Image.file(
              File(weather!.localImagePath!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to gradient/icon if file not found
                return const SizedBox.shrink();
              },
            )
          else if (weather!.imageBase64 != null)
            Image.memory(
              base64Decode(weather!.imageBase64!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getWeatherIcon(weather!.mainCondition),
                    size: 200,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  if (isLoading && loadingMessage != null) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      loadingMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 2,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Text Overlay
          Positioned(
            top: 100, // Positioned in the top third
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // City, State/Province
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    weather!.cityName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color:
                          _parseColor(weather!.fontColor) ??
                          const Color(0xFF333333), // Dynamic or Dark Grey
                      shadows: [
                        const Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Weather Icon and Temperature
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getWeatherIcon(weather!.mainCondition),
                      size: 40,
                      color:
                          _parseColor(weather!.fontColor) ??
                          const Color(0xFF333333),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${weather!.temperature.round()}°F',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                        color:
                            _parseColor(weather!.fontColor) ??
                            const Color(0xFF333333),
                        shadows: [
                          const Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 2,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Longform Date
                Text(
                  _formatDate(weather!.date),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color:
                        _parseColor(weather!.fontColor) ??
                        const Color(0xFF555555),
                    shadows: [
                      const Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 2,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getBackgroundColors(String condition) {
    // Soft pastel gradients to match the "cute" 3D aesthetic
    switch (condition.toLowerCase()) {
      case 'clear':
        return [
          const Color(0xFFE0F7FA),
          const Color(0xFFE0F7FA),
        ]; // Solid Pale Blue
      case 'clouds':
        return [
          const Color(0xFFF5F5F5),
          const Color(0xFFF5F5F5),
        ]; // Solid Off-White
      case 'rain':
      case 'drizzle':
        return [
          const Color(0xFFE3F2FD),
          const Color(0xFFE3F2FD),
        ]; // Solid Very Light Blue
      case 'thunderstorm':
        return [
          const Color(0xFFE8EAF6),
          const Color(0xFFE8EAF6),
        ]; // Solid Pale Indigo
      case 'snow':
        return [
          const Color(0xFFFAFAFA),
          const Color(0xFFFAFAFA),
        ]; // Solid White
      case 'fog':
      case 'mist':
      case 'haze':
      case 'smoke':
      case 'dust':
      case 'sand':
      case 'ash':
        return [
          const Color(0xFFCFD8DC),
          const Color(0xFFCFD8DC),
        ]; // Solid Blue Grey
      case 'squall':
      case 'tornado':
        return [
          const Color(0xFF607D8B),
          const Color(0xFF607D8B),
        ]; // Darker Blue Grey
      default:
        return [const Color(0xFFE0F7FA), const Color(0xFFE0F7FA)];
    }
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.umbrella;
      case 'snow':
        return Icons.ac_unit;
      case 'fog':
      case 'mist':
      case 'haze':
      case 'smoke':
      case 'dust':
      case 'sand':
      case 'ash':
        return Icons.blur_on;
      case 'squall':
      case 'tornado':
        return Icons.cyclone;
      default:
        return Icons.wb_cloudy;
    }
  }

  String _formatDate(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, $monthName ${date.day}';
  }

  Color? _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      if (hexColor.length == 6 || hexColor.length == 7) buffer.write('ff');
      buffer.write(hexColor.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return null;
    }
  }
}
