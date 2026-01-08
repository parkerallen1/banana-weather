class Location {
  final String name;
  final double lat;
  final double lon;

  Location({required this.name, required this.lat, required this.lon});

  Map<String, dynamic> toJson() {
    return {'name': name, 'lat': lat, 'lon': lon};
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(name: json['name'], lat: json['lat'], lon: json['lon']);
  }
}
