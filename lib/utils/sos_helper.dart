import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class SosHelper {
  
  static Future<void> sendSosMessage(String type) async {
    String message = "ACİL: Deprem oldu, yardıma ihtiyacım var!";
    
    // Try to get location
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
           permission = await Geolocator.requestPermission();
        }
        
        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
           final Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
           // Google Maps Link
           final String mapLink = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
           message += "\nKonumum: $mapLink";
           message += "\n(Koordinat: ${position.latitude}, ${position.longitude})";
        }
      }
    } catch (e) {
      // Ignore location error, send basic message
      print("Location error: $e");
    }

    message += "\n\nBu mesaj Earthquake App üzerinden gönderilmiştir.";

    final Uri url;
    if (type == 'sms') {
      // Target 112 explicitly as requested
      // Note: On some Android devices, the body might not populate if a number is set, 
      // but 'sms:112?body=...' is the standard attempt.
      url = Uri.parse('sms:112?body=${Uri.encodeComponent(message)}');
    } else {
      // WhatsApp - using universal link
      // Universal link doesn't support pre-filling number unless we know it.
      // We'll leave it empty so user picks contact/group.
      url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback for WhatsApp if universal link fails, or just debug print
      print("Could not launch $url");
      // Try launching without check if possible or show error
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        throw 'Mesajcı açılamadı: $url';
      }
    }
  }
}
