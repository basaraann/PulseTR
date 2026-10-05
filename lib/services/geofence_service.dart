import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/earthquake_model.dart';

class GeofenceService {
  Future<Earthquake?> checkProximity(List<Earthquake> earthquakes) async {
    // 1. Get Permission & Location
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    final position = await Geolocator.getCurrentPosition();
    final userLat = position.latitude;
    final userLng = position.longitude;

    const Distance distance = Distance();
    
    for (var eq in earthquakes) {
      // Alert Condition: > 4.0 magnitude AND within 100km AND recent (last 2 hours)
      // Note: API returns dynamic time, ensuring we check valid data
      if (eq.magnitude >= 4.0 && DateTime.now().difference(eq.time).inHours < 2) {
         final double km = distance.as(LengthUnit.Kilometer, LatLng(userLat, userLng), LatLng(eq.latitude, eq.longitude));
         
         if (km < 100) {
            // Return the first matching earthquake to trigger alert
            // We can attach the distance to the earthquake object or return a tuple if needed, 
            // but for now let's just return the earthquake and re-calc distance or handle it in UI.
            // Actually, better to return a custom result or just the earthquake and let UI handle message.
            // Let's attach distance temporarily or just recalculate.
            // For simplicity, let's just return it. 
            // Or better, let's return a record or simple wrapper?
            // "Tuple" is not standard in old Dart, but Records are in Dart 3. 
            // Let's assume Dart 3 given the recent packages.
            return eq; 
         }
      }
    }
    return null;
  }
  
  // Helper to calculate distance for the UI message
  double calculateDistance(double userLat, double userLng, double eqLat, double eqLng) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, LatLng(userLat, userLng), LatLng(eqLat, eqLng));
  }
  
  Future<Position?> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition();
  }
}
