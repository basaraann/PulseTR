class Earthquake {
  final String id;
  final double magnitude;
  final String place;
  final DateTime time;
  final String url;
  final double depth;
  final double latitude;
  final double longitude;

  Earthquake({
    required this.id,
    required this.magnitude,
    required this.place,
    required this.time,
    required this.url,
    required this.depth,
    required this.latitude,
    required this.longitude,
  });

  factory Earthquake.fromJson(Map<String, dynamic> json) {
    // Kandilli API Format to Internal Model
    // Example: {"_id": "...", "mag": 3.2, "title": "YER-SEHIR", "date": "2023.01.01 10:00:00", "depth": 5.4}
    
    // Parse Date (Format: yyyy.MM.dd HH:mm:ss or yyyy-MM-dd HH:mm:ss)
    DateTime parsedTime;
    try {
      // API uses 'date_time' typically, older might use 'date'.
      final dateStr = (json['date_time'] ?? json['date'] ?? '').toString();
      parsedTime = DateTime.parse(dateStr.replaceAll('.', '-'));
    } catch (e) {
      // Fallback only if parsing really fails (should not happen with correct key)
      // print("Date parse error: $e"); 
      // Instead of now(), let's try to parse 'created_at' timestamp if available
      if (json['created_at'] != null) {
        parsedTime = DateTime.fromMillisecondsSinceEpoch(json['created_at'] * 1000);
      } else {
        parsedTime = DateTime.now();
      }
    }

    // Parse primitive values first
    final double magnitude = (json['mag'] as num).toDouble();
    final String place = json['title'] ?? 'Unknown Location';
    final double depth = (json['depth'] as num).toDouble();
    final double lat = (json['geojson'] != null) ? (json['geojson']['coordinates'][1] as num).toDouble() : (json['lat'] ?? 0.0);
    final double lng = (json['geojson'] != null) ? (json['geojson']['coordinates'][0] as num).toDouble() : (json['lng'] ?? 0.0);
    final String url = 'http://koeri.boun.edu.tr/scripts/lst0.asp';
    
    // Generate deterministic ID
    final generatedId = "${parsedTime.millisecondsSinceEpoch}_${lat}_${lng}_${magnitude}";
    
    final String finalId = (json['_id'] != null && json['_id'].toString().isNotEmpty) 
        ? json['_id'].toString() 
        : generatedId;

    return Earthquake(
      id: finalId,
      magnitude: magnitude,
      place: place,
      time: parsedTime,
      url: url,
      depth: depth,
      latitude: lat,
      longitude: lng,
    );
  }
}
