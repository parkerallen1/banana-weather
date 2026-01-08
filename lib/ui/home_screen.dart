import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/location_model.dart';
import '../models/weather_model.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/weather_service.dart';
import '../services/log_service.dart';
import 'debug_log_screen.dart';
import 'weather_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();

  List<Location> _savedLocations = [];
  final Map<int, Weather> _weatherCache = {};
  final Map<int, String> _loadingStatus = {};
  final Map<int, String> _errorState = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    await _loadSavedLocations();
    await _loadSavedWeather();
    // After loading saved data, refresh current location if needed
    if (!_weatherCache.containsKey(0)) {
      _fetchCurrentLocationWeather();
    }
  }

  Future<void> _loadSavedWeather() async {
    final cache = await _storageService.getSavedWeatherCache();
    if (mounted) {
      setState(() {
        _weatherCache.addAll(cache);
      });
    }
  }

  Future<void> _loadSavedLocations() async {
    final locations = await _storageService.getSavedLocations();
    setState(() {
      _savedLocations = locations;
    });
    // Fetch weather for saved locations if not in cache
    for (int i = 0; i < locations.length; i++) {
      if (!_weatherCache.containsKey(i + 1)) {
        _fetchWeatherForIndex(
          i + 1,
          locations[i],
        ); // +1 because 0 is current location
      }
    }
  }

  Future<void> _fetchCurrentLocationWeather() async {
    LogService.instance.log('HomeScreen: Fetching current location weather...');
    setState(() {
      _loadingStatus[0] = "Getting current location...";
      _errorState.remove(0);
    });

    try {
      final location = await _locationService.getCurrentLocation();
      LogService.instance.log(
        'HomeScreen: Got location: ${location.lat}, ${location.lon}',
      );

      if (!mounted) return;
      setState(() {
        _loadingStatus[0] = "Fetching weather data...";
      });

      final weather = await _weatherService.getWeather(
        location.lat,
        location.lon,
      );
      LogService.instance.log(
        'HomeScreen: Got weather for current location: ${weather.cityName}',
      );

      if (!mounted) return;
      setState(() {
        _weatherCache[0] = weather;
        _loadingStatus[0] = "Generating immersive view...";
      });
      _storageService.saveWeatherCache(_weatherCache);

      // Generate Image with Timeout
      try {
        final imageBase64 = await _weatherService
            .generateImage(weather)
            .timeout(
              const Duration(seconds: 25),
              onTimeout: () {
                LogService.instance.log(
                  'HomeScreen: Image generation timed out',
                );
                return null;
              },
            );

        if (imageBase64 != null) {
          final updatedWeather = weather.copyWith(imageBase64: imageBase64);
          if (mounted) {
            setState(() {
              _weatherCache[0] = updatedWeather;
            });
            _storageService.saveWeatherCache(_weatherCache);
          }
        }
      } catch (e) {
        LogService.instance.log('HomeScreen: Error generating image: $e');
      }

      if (mounted) {
        setState(() {
          _loadingStatus.remove(0);
        });
      }
    } catch (e) {
      LogService.instance.log(
        'HomeScreen: Error fetching current location weather: $e',
      );
      if (mounted) {
        setState(() {
          _loadingStatus.remove(0);
          _errorState[0] = e.toString();
        });
      }
    }
  }

  Future<void> _fetchWeatherForIndex(int index, Location location) async {
    LogService.instance.log(
      'HomeScreen: Fetching weather for index $index (${location.name})',
    );
    setState(() {
      _loadingStatus[index] = "Fetching weather data...";
      _errorState.remove(index);
    });

    try {
      final weather = await _weatherService.getWeatherByCity(location.name);
      LogService.instance.log(
        'HomeScreen: Got weather for index $index: ${weather.cityName}',
      );

      if (!mounted) return;
      setState(() {
        _weatherCache[index] = weather;
        _loadingStatus[index] = "Generating immersive view...";
      });
      _storageService.saveWeatherCache(_weatherCache);

      // Generate Image with Timeout
      try {
        final imageBase64 = await _weatherService
            .generateImage(weather)
            .timeout(
              const Duration(seconds: 25),
              onTimeout: () {
                LogService.instance.log(
                  'HomeScreen: Image generation timed out',
                );
                return null;
              },
            );

        if (imageBase64 != null) {
          final updatedWeather = weather.copyWith(imageBase64: imageBase64);
          if (mounted) {
            setState(() {
              _weatherCache[index] = updatedWeather;
            });
            _storageService.saveWeatherCache(_weatherCache);
          }
        }
      } catch (e) {
        LogService.instance.log('HomeScreen: Error generating image: $e');
      }

      if (mounted) {
        setState(() {
          _loadingStatus.remove(index);
        });
      }
    } catch (e) {
      LogService.instance.log(
        'HomeScreen: Error fetching weather for index $index: $e',
      );
      if (mounted) {
        setState(() {
          _loadingStatus.remove(index);
          _errorState[index] = e.toString();
        });
      }
    }
  }

  Future<void> _addLocation(String cityName) async {
    LogService.instance.log('HomeScreen: Adding location: $cityName');
    try {
      // Verify city exists and get coords
      final weather = await _weatherService.getWeatherByCity(cityName);
      LogService.instance.log('HomeScreen: Found city: ${weather.cityName}');
      final newLocation = Location(
        name: weather.cityName,
        lat: weather.lat,
        lon: weather.lon,
      );

      setState(() {
        _savedLocations.add(newLocation);
      });
      _storageService.saveLocations(_savedLocations);

      // Fetch weather for the new location (index is length - 1 + 1 = length)
      int newIndex = _savedLocations.length;
      setState(() {
        _weatherCache[newIndex] = weather;
        _loadingStatus[newIndex] = "Generating immersive view...";
      });
      _storageService.saveWeatherCache(_weatherCache);

      // Scroll to new page
      _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // Generate Image with Timeout
      try {
        final imageBase64 = await _weatherService
            .generateImage(weather)
            .timeout(
              const Duration(seconds: 25),
              onTimeout: () {
                LogService.instance.log(
                  'HomeScreen: Image generation timed out',
                );
                return null;
              },
            );

        if (imageBase64 != null) {
          final updatedWeather = weather.copyWith(imageBase64: imageBase64);
          if (mounted) {
            setState(() {
              _weatherCache[newIndex] = updatedWeather;
            });
            _storageService.saveWeatherCache(_weatherCache);
          }
        }
      } catch (e) {
        LogService.instance.log('HomeScreen: Error generating image: $e');
      }

      if (mounted) {
        setState(() {
          _loadingStatus.remove(newIndex);
        });
      }
    } catch (e) {
      LogService.instance.log('HomeScreen: Error adding location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find city: $cityName')),
        );
      }
    }
  }

  Future<void> _showAddLocationDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Location',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'City Name (e.g. Mordor)',
            hintStyle: GoogleFonts.outfit(color: Colors.grey),
          ),
          style: GoogleFonts.outfit(),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              'Add',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _addLocation(result);
    }
  }

  Future<void> _refreshWeather(int index) async {
    LogService.instance.log(
      'HomeScreen: Refreshing weather for index $index (keeping image)',
    );
    try {
      Weather? newWeather;
      if (index == 0) {
        final location = await _locationService.getCurrentLocation();
        newWeather = await _weatherService.getWeather(
          location.lat,
          location.lon,
        );
      } else {
        final location = _savedLocations[index - 1];
        newWeather = await _weatherService.getWeatherByCity(location.name);
      }

      if (mounted) {
        setState(() {
          // Preserve the existing image if available
          final oldWeather = _weatherCache[index];
          if (oldWeather != null) {
            newWeather = newWeather!.copyWith(
              imageBase64: oldWeather.imageBase64,
              localImagePath: oldWeather.localImagePath,
              imagePrompt: oldWeather.imagePrompt,
            );
          }
          _weatherCache[index] = newWeather!;
        });
        _storageService.saveWeatherCache(_weatherCache);
      }
    } catch (e) {
      LogService.instance.log('HomeScreen: Error refreshing weather: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh weather: $e')),
        );
      }
    }
  }

  void _onRefreshPressed() {
    if (_currentIndex == 0) {
      _fetchCurrentLocationWeather();
    } else {
      _fetchWeatherForIndex(_currentIndex, _savedLocations[_currentIndex - 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages =
        1 + _savedLocations.length; // 0 is current, rest are saved

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow content to go behind app bar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 8),
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
            onPressed: _onRefreshPressed,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: _showAddLocationDialog,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            itemBuilder: (context, index) {
              return KeepAlivePage(
                child: RefreshIndicator(
                  onRefresh: () => _refreshWeather(index),
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height,
                      child: Builder(
                        builder: (context) {
                          if (index == 0) {
                            return WeatherCard(
                              weather: _weatherCache[0],
                              isLoading: _loadingStatus.containsKey(0),
                              loadingMessage: _loadingStatus[0],
                              errorMessage: _errorState[0],
                              onRetry: _fetchCurrentLocationWeather,
                            );
                          } else {
                            final location = _savedLocations[index - 1];
                            // If we don't have weather yet, try to fetch it (if not loading)
                            if (!_weatherCache.containsKey(index) &&
                                !_loadingStatus.containsKey(index)) {
                              if (_weatherCache[index] == null) {
                                _weatherService
                                    .getWeatherByCity(location.name)
                                    .then((w) {
                                      if (mounted) {
                                        setState(() {
                                          _weatherCache[index] = w;
                                        });
                                      }
                                    })
                                    .catchError((e) {});
                              }
                            }

                            return WeatherCard(
                              weather: _weatherCache[index],
                              isLoading: _loadingStatus.containsKey(index),
                              loadingMessage: _loadingStatus[index],
                              errorMessage: _errorState[index],
                              onRetry: () {
                                if (index == 0) {
                                  _fetchCurrentLocationWeather();
                                } else {
                                  _fetchWeatherForIndex(
                                    index,
                                    _savedLocations[index - 1],
                                  );
                                }
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              // If we swipe to a page and it has no data, fetch it.
              // This covers the "never loaded" case if the initial loop failed or was skipped.
              if (!_weatherCache.containsKey(index) &&
                  !_loadingStatus.containsKey(index)) {
                if (index == 0) {
                  _fetchCurrentLocationWeather();
                } else {
                  _fetchWeatherForIndex(index, _savedLocations[index - 1]);
                }
              }
            },
          ),
          // Page Indicator (Dots)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
          // Debug Log Button
          Positioned(
            bottom: 20,
            left: 20,
            child: SafeArea(
              child: FloatingActionButton.small(
                heroTag: 'debug_btn',
                backgroundColor: Colors.black45,
                child: const Icon(Icons.bug_report, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DebugLogScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KeepAlivePage extends StatefulWidget {
  final Widget child;

  const KeepAlivePage({super.key, required this.child});

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
