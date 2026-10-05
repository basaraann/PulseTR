import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/earthquake_model.dart';
import 'api_service.dart';

// Bildirim kanalı ID'si
const String channelId = "earthquake_alert_channel";
const String channelName = "Earthquake Alerts";
const String notificationId = "earthquake_service_notification";

// Global instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // Dart Plugin Registration if needed (for some plugins)
  DartPluginRegistrant.ensureInitialized();

  // Initialize SharedPreferences inside the background isolate
  // (In some versions of shared_preferences/flutter, this might need special handling, 
  // but generally works if awaited).
  
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Periyodik Timer Başlat (Daha sık kontrol: 10 saniye)
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Servis çalışıyor bildirimi
      }
    }
    
    await _checkEarthquakes();
  });
}

Future<void> _checkEarthquakes() async {
  print("Deprem kontrol servisi çalışıyor (FlutterBackgroundService)...");
  try {
    final apiService = ApiService();
    // fetchEarthquakes metodunun background isolate'da çalışacağından emin olun 
    final earthquakes = await apiService.fetchEarthquakes();
    
    if (earthquakes.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force reload to ensure fresh state
    final lastAlertedEarthquakeId = prefs.getString('lastAlertedEarthquakeId');
    
    // User Preferences
    final double minMag = prefs.getDouble('pref_min_magnitude') ?? 1.0; 
    final double maxDist = prefs.getDouble('pref_max_distance') ?? 500.0;

    // Sort descending by time
    earthquakes.sort((a, b) => b.time.compareTo(a.time));
    final latestEarthquake = earthquakes.first;
    
    final List<String> alertedIds = prefs.getStringList('alerted_earthquake_ids') ?? [];

    // Check if already alerted
    if (lastAlertedEarthquakeId == latestEarthquake.id || alertedIds.contains(latestEarthquake.id)) {
       return;
    }

    // Check time freshness (Sadece son 15 dakika)
    if (DateTime.now().difference(latestEarthquake.time).inMinutes > 15) {
       return;
    }
    
    // STRICT LOGIC
    bool shouldNotify = false;
    String body = "${latestEarthquake.place} - ${latestEarthquake.magnitude}";
    String title = "DEPREM: ${latestEarthquake.magnitude}";

    // Check Distance FIRST with Fallback
    double? km;
    try {
       Position? position;
       try {
          // Background location might require checking permission again or handling timeouts
          position = await Geolocator.getLastKnownPosition();
          position ??= await Geolocator.getCurrentPosition(
             desiredAccuracy: LocationAccuracy.medium,
             timeLimit: const Duration(seconds: 5)
          );
       } catch (e) {
          print("Background Loc Error: $e");
       }

       // Fallback to cache if live location failed
       if (position == null) {
          final double? cachedLat = prefs.getDouble('cached_latitude');
          final double? cachedLng = prefs.getDouble('cached_longitude');
          if (cachedLat != null && cachedLng != null) {
              position = Position(
                latitude: cachedLat, 
                longitude: cachedLng, 
                timestamp: DateTime.now(), 
                accuracy: 0, 
                altitude: 0, 
                heading: 0, 
                speed: 0, 
                speedAccuracy: 0, 
                altitudeAccuracy: 0, 
                headingAccuracy: 0
             );
          }
       }

       if (position != null) {
          final Distance distance = const Distance();
          km = distance.as(LengthUnit.Meter, 
             LatLng(position.latitude, position.longitude), 
             LatLng(latestEarthquake.latitude, latestEarthquake.longitude)
          ) / 1000;
       }
    } catch (e) {
       // Loc failed.
    }
    
    // Uygula: KATI KURAL
    if (km != null) {
       if (km <= maxDist) {
          // Mesafe uygunsa, büyüklüğe bak
          if (latestEarthquake.magnitude >= minMag) {
               shouldNotify = true;
               body += "\n(${km.toStringAsFixed(1)} km)";
          }
       }
    } else {
       // Konum yoksa bildirim yok (Sadece 6.0+ için aşağıda kural var)
    }

    // Safety Net: > 6.0 always notify (Ulusal Acil Durum)
    if (latestEarthquake.magnitude >= 6.0) {
       shouldNotify = true;
       title = "🚨 ACİL: BÜYÜK DEPREM (${latestEarthquake.magnitude})";
    }

    if (shouldNotify) {
        await _showNotification(latestEarthquake, body, title: title);
        
        await prefs.setString('lastAlertedEarthquakeId', latestEarthquake.id);
        
        // Add to shared list
        if (!alertedIds.contains(latestEarthquake.id)) {
            alertedIds.add(latestEarthquake.id);
            if (alertedIds.length > 50) {
                alertedIds.removeRange(0, alertedIds.length - 50);
            }
            await prefs.setStringList('alerted_earthquake_ids', alertedIds);
        }
    }

  } catch (e) {
    print("Arka plan hatası: $e");
  }
}

Future<void> _showNotification(Earthquake earthquake, String body, {String? title}) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: 'Deprem Bildirimleri',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true, // Kullanıcı varsayılan bildirim tonunu istiyor
    enableVibration: true,
    fullScreenIntent: true,
    styleInformation: BigTextStyleInformation(''),
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecond, // Unique ID
    title ?? 'DEPREM: ${earthquake.magnitude}',
    body,
    platformChannelSpecifics,
  );
}

class BackgroundService {
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Bildirimleri hazırla
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create Notification Channel explicitly for Android 14+
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'Deprem Bildirimleri',
      importance: Importance.max,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Servisi konfigüre et
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // Bu, onStart fonksiyonunun çağrılacağı yerdir
        onStart: onStart,

        // Servis ön planda çalışırken kullanıcıya gösterilecek bildirim
        autoStart: true,
        isForegroundMode: true,
        
        notificationChannelId: channelId, // Aynı kanalı kullanabiliriz veya farklı bir tane
        initialNotificationTitle: 'Deprem Takip Servisi',
        initialNotificationContent: 'Depremleri arka planda izliyor...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        // iOS arka plan desteği sınırlıdır, ancak yine de fetch özelliğini dener
        autoStart: true,
        onForeground: onStart,
        onBackground: onStartIos,
      ),
    );
  }

  void registerPeriodicTask() {
    // FlutterBackgroundService kullanırken buna gerek yok (otomatik timer başlattık),
    // ama main.dart içindeki çağrıyı bozmamak için boş bırakıyoruz.
  }
}

@pragma('vm:entry-point')
Future<bool> onStartIos(ServiceInstance service) async {
  // iOS background fetch logic if needed
  // iOS limitations often prevent long running tasks.
  // We can try to do a single check.
  WidgetsFlutterBinding.ensureInitialized();
  await _checkEarthquakes();
  return true;
}
