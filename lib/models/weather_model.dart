class Weather {
  final String cityName;
  final double temperature;
  final String mainCondition;
  final String description;
  final String iconCode;
  final DateTime date;
  final double lat;
  final double lon;
  final String? imagePrompt;
  final String? imageBase64;
  final String? localImagePath;
  final List<String> landmarks;
  final String? fontColor;
  final String? backgroundColor;

  Weather({
    required this.cityName,
    required this.temperature,
    required this.mainCondition,
    required this.description,
    required this.iconCode,
    required this.date,
    required this.lat,
    required this.lon,
    this.imagePrompt,
    this.imageBase64,
    this.localImagePath,
    this.landmarks = const [],
    this.fontColor,
    this.backgroundColor,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      cityName: json['name'],
      temperature: (json['main']['temp'] as num).toDouble(),
      mainCondition: json['weather'][0]['main'],
      description: json['weather'][0]['description'],
      iconCode: json['weather'][0]['icon'],
      date: DateTime.now(),
      lat: (json['coord']['lat'] as num).toDouble(),
      lon: (json['coord']['lon'] as num).toDouble(),
      imagePrompt: json['imagePrompt'],
      imageBase64: json['imageBase64'],
      fontColor: json['fontColor'],
      backgroundColor: json['backgroundColor'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cityName': cityName,
      'temperature': temperature,
      'mainCondition': mainCondition,
      'description': description,
      'iconCode': iconCode,
      'date': date.toIso8601String(),
      'lat': lat,
      'lon': lon,
      'imagePrompt': imagePrompt,

      'localImagePath': localImagePath,
      'landmarks': landmarks,
      'fontColor': fontColor,
      'backgroundColor': backgroundColor,
    };
  }

  factory Weather.fromStorage(Map<String, dynamic> json) {
    return Weather(
      cityName: json['cityName'],
      temperature: (json['temperature'] as num).toDouble(),
      mainCondition: json['mainCondition'],
      description: json['description'],
      iconCode: json['iconCode'],
      date: DateTime.parse(json['date']),
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      imagePrompt: json['imagePrompt'],

      localImagePath: json['localImagePath'],
      landmarks: List<String>.from(json['landmarks'] ?? []),
      fontColor: json['fontColor'],
      backgroundColor: json['backgroundColor'],
    );
  }
  Weather copyWith({
    String? cityName,
    double? temperature,
    String? mainCondition,
    String? description,
    String? iconCode,
    DateTime? date,
    double? lat,
    double? lon,
    String? imagePrompt,
    String? imageBase64,
    String? localImagePath,
    List<String>? landmarks,
    String? fontColor,
    String? backgroundColor,
  }) {
    return Weather(
      cityName: cityName ?? this.cityName,
      temperature: temperature ?? this.temperature,
      mainCondition: mainCondition ?? this.mainCondition,
      description: description ?? this.description,
      iconCode: iconCode ?? this.iconCode,
      date: date ?? this.date,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      imagePrompt: imagePrompt ?? this.imagePrompt,
      imageBase64: imageBase64 ?? this.imageBase64,
      localImagePath: localImagePath ?? this.localImagePath,
      landmarks: landmarks ?? this.landmarks,
      fontColor: fontColor ?? this.fontColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}
