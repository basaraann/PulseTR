import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/earthquake_model.dart';
import 'api_service.dart';
import '../utils/notification_helper.dart';

class EarthquakeManager {
  static final EarthquakeManager _instance = EarthquakeManager._internal();
  factory EarthquakeManager() => _instance;
  EarthquakeManager._internal();

  final ApiService _apiService = ApiService();
  final NotificationHelper _notificationHelper = NotificationHelper();
  
  // ValueNotifier ensures listeners are notified only when the object changes.
  // We will emit a new list instance to trigger updates.
  final ValueNotifier<List<Earthquake>> earthquakesNotifier = ValueNotifier([]);
  final ValueNotifier<DateTime?> lastUpdateNotifier = ValueNotifier(null);
  
  Timer? _timer;
  Earthquake? _processedTestEarthquake; // To avoid re-notifying for the same test

  void startPeriodicFetch() {
    _fetchData(); // Initial fetch
    _timer?.cancel();
    // Polling: 10 saniyede bir. 1sn agresif/rate-limit riski vardı, ayrıca
    // Kandilli zaten saniyede güncellenmiyor.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
  }

  void stopPeriodicFetch() {
    _timer?.cancel();
  }

  Future<void> _fetchData() async {
    try {
      final newEarthquakes = await _apiService.fetchEarthquakes();
      
      final currentList = earthquakesNotifier.value;
      
      // If we have a test earthquake injected locally that is OLDER than the API update, 
      // we might want to keep it or discard it. For simpler logic, we just overwrite with API 
      // unless we merge. Let's strictly rely on API for now, BUT if we want "Test Alarm" 
      // to appear on UI, we must merge it.
      
      List<Earthquake> finalList = List.from(newEarthquakes);
      
      // Re-insert test earthquake if it's recent (e.g. within last 1 minute)
      if (_processedTestEarthquake != null) {
         final diff = DateTime.now().difference(_processedTestEarthquake!.time);
         if (diff.inSeconds < 60) {
            finalList.insert(0, _processedTestEarthquake!);
         } else {
            _processedTestEarthquake = null;
         }
      }

      // Check if data changed meaningfully
      // NOTE: User wants "constant" updates. Even if data is same, refreshing might be reassuring? 
      // But typically we should avoid rebuilds. However, if user thinks it is stuck, maybe we should 
      // allow rebuilds or at least log.
      // Let's keep the check but make it verify if the timestamp of the first item changed?
      // Actually, if ID is same, list is likely same.
      // To satisfy "Surekli guncellensin" (constantly update), we can just remove this return.
      // Or we can add a 'lastUpdated' timestamp to the provider so UI shows "Updated: 12:45:01".
      
      // if (currentList.isNotEmpty && finalList.isNotEmpty) {
      //    if (currentList.first.id == finalList.first.id && currentList.length == finalList.length) {
      //       return; 
      //    }
      // }
      
      // Notify Listeners
      // Force sort by date descending to ensure latest is ALWAYS top
      finalList.sort((a, b) => b.time.compareTo(a.time));
      
      earthquakesNotifier.value = finalList;
      lastUpdateNotifier.value = DateTime.now();
      
      // Check for notifications for the NEWEST API earthquake
      // IMPORTANT: Sort by time first to handle out-of-order API responses
      if (newEarthquakes.isNotEmpty) {
         newEarthquakes.sort((a, b) => b.time.compareTo(a.time));
         _checkForNotification(newEarthquakes.first);
      }

    } catch (e) {
      debugPrint("EarthquakeManager Error: $e");
    }
  }
  
  String? _lastNotifiedEarthquakeId;
  bool _isFirstFetch = true;

  Future<void> _checkForNotification(Earthquake latest) async {
    if (_isFirstFetch) {
      _isFirstFetch = false;
      // İlk açılışta en son depremi "bildirilmiş" olarak işaretleyelim ki hemen ötmesin
      _saveAlertedId(latest.id);
      return;
    }

    // Basit kontrol: Eğer bu ID zaten hafızadaysa çık
    if (_lastNotifiedEarthquakeId == latest.id) return;
    
    try {
       final prefs = await SharedPreferences.getInstance();
       final List<String> alertedIds = prefs.getStringList('alerted_earthquake_ids') ?? [];
       
       // Eğer bu deprem daha önce bildirilmişse çık
       if (alertedIds.contains(latest.id)) {
          _lastNotifiedEarthquakeId = latest.id;
          return;
       }

       final double minMag = prefs.getDouble('pref_min_magnitude') ?? 1.0; 
       final double maxDist = prefs.getDouble('pref_max_distance') ?? 500.0;
       
       // Calculate Distance with Fallback
       double? km;
       try {
         // Konumu almayı dene
         Position? position = await Geolocator.getLastKnownPosition();
         position ??= await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium, 
            timeLimit: const Duration(seconds: 5)
         );

         if (position != null) {
            // Konum başarılıysa önbelleğe kaydet
            prefs.setDouble('cached_latitude', position.latitude);
            prefs.setDouble('cached_longitude', position.longitude);
         } else {
            // Konum alınamadıysa önbellekten oku
            final double? cachedLat = prefs.getDouble('cached_latitude');
            final double? cachedLng = prefs.getDouble('cached_longitude');
            if (cachedLat != null && cachedLng != null) {
               // Fake position object from cache
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
                LatLng(latest.latitude, latest.longitude)
             ) / 1000;
         }

       } catch (e) {
          debugPrint("Location error: $e");
          // Konum tamamen başarısızsa cache devreye girsin (yukarıda yapıldı)
       }

       // STRICT LOGIC UYGULAMASI
       bool shouldNotify = false;
       String title = "DEPREM: ${latest.magnitude}";
       String body = "${latest.place}";

       // 1. Mesafe Kontrolü (Varsa)
       if (km != null) {
          // Eğer mesafe bilgisi varsa, mutlaka mesafe sınırına uymalı
          if (km <= maxDist) {
             body += "\n(${km.toStringAsFixed(1)} km)";
             
             // 2. Büyüklük Kontrolü
             if (latest.magnitude >= minMag) {
                shouldNotify = true;
             }
          }
       } else {
          // Konum HİÇBİR ŞEKİLDE bulunamadıysa (cache dahil yoksa)
          // Sadece çok büyük depremlerde haber ver (Safety Net)
          // Kullanıcı "katı kurallar" istediği için, konumu bilmiyorsak varsayım yapmıyoruz.
       }
       
       // ACİL DURUM: 6.0 ve üzeri her zaman bildirilsin (Ulusal Güvenlik/Hayat Memat)
       if (latest.magnitude >= 6.0) {
          shouldNotify = true;
          title = "🚨 ACİL: BÜYÜK DEPREM (${latest.magnitude})";
          // Mesafeyi bilmiyorsak bile uyar
       }

       if (shouldNotify) {
          _notificationHelper.showEarthquakeNotification(title, body);
          _saveAlertedId(latest.id);
          _lastNotifiedEarthquakeId = latest.id;
       }

    } catch (e) {
      debugPrint("Notification check error: $e");
    }
  }

  Future<void> _saveAlertedId(String id) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        List<String> alertedIds = prefs.getStringList('alerted_earthquake_ids') ?? [];
        if (!alertedIds.contains(id)) {
           alertedIds.add(id);
           // Son 50 tanesini tut, gerisini sil (performans için)
           if (alertedIds.length > 50) {
              alertedIds = alertedIds.sublist(alertedIds.length - 50);
           }
           await prefs.setStringList('alerted_earthquake_ids', alertedIds);
        }
      } catch (e) {
         debugPrint("Error saving alerted ID: $e");
      }
  }

  void injectTestEarthquake() {
    final fake = Earthquake(
       id: 'test_${DateTime.now().millisecondsSinceEpoch}',
       magnitude: 7.4,
       place: 'TEST: Deprem Senaryosu',
       time: DateTime.now(),
       url: 'https://example.com',
       depth: 10.0,
       latitude: 39.0, // Near center for visibility
       longitude: 35.0,
    );
    
    _processedTestEarthquake = fake;
    
    // Immediate update
    var currentList = List<Earthquake>.from(earthquakesNotifier.value);
    currentList.insert(0, fake);
    earthquakesNotifier.value = currentList;
    
    // Also trigger notification
    _notificationHelper.showEarthquakeNotification(
       "TEST ALARMI", 
       "7.4 Simülasyon Depremi"
    );
  }
}
