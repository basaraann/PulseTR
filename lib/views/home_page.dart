import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/earthquake_model.dart';
import '../services/earthquake_manager.dart'; // Singleton
import '../services/api_service.dart';
import '../services/geofence_service.dart';
import 'detail_page.dart';
import 'map_page.dart';
import 'emergency/emergency_menu_page.dart';
import 'intro/notification_settings_page.dart' as import_settings;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final EarthquakeManager _manager = EarthquakeManager();
  final GeofenceService _geofenceService = GeofenceService();

  @override
  void initState() {
    super.initState();
    // Check onboarding
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());

    // Start periodic fetch
    _manager.startPeriodicFetch();
    
    // Listen for proximity checks
    _manager.earthquakesNotifier.addListener(_onDataUpdated);
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final bool seen = prefs.getBool('seen_onboarding') ?? false;
    if (!seen && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const import_settings.NotificationSettingsPage()),
      );
    }
  }

  @override
  void dispose() {
    _manager.earthquakesNotifier.removeListener(_onDataUpdated);
    super.dispose();
  }

  void _onDataUpdated() {
    _checkProximity(_manager.earthquakesNotifier.value);
  }

  Future<void> _checkProximity(List<Earthquake> earthquakes) async {
    try {
      if (earthquakes.isEmpty) return;

      final earthquake = await _geofenceService.checkProximity(earthquakes);
      
      if (earthquake != null) {
         final position = await _geofenceService.getCurrentPosition();
         if (position != null) {
            final dist = _geofenceService.calculateDistance(position.latitude, position.longitude, earthquake.latitude, earthquake.longitude);
            _showProximityAlert(earthquake, dist);
         }
      }
    } catch (e) {
      print("Proximity check error: $e");
    }
  }

  void _showProximityAlert(Earthquake eq, double km) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠️ DİKKAT: ${km.toStringAsFixed(1)}km yakınınızda ${eq.magnitude} büyüklüğünde deprem oldu! (${eq.place})'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'DETAY',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DetailPage(earthquake: eq)),
            );
          },
        ),
      )
    );
  }

  Color _getColorForMagnitude(double magnitude) {
    if (magnitude < 3.0) return const Color(0xFF4ADE80); // Green 400
    if (magnitude < 5.0) return const Color(0xFFFACC15); // Yellow 400
    if (magnitude < 7.0) return const Color(0xFFFB923C); // Orange 400
    return const Color(0xFFF87171); // Red 400
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Anlık Depremler', style: TextStyle(fontSize: 20)),
            ValueListenableBuilder<DateTime?>(
              valueListenable: _manager.lastUpdateNotifier,
              builder: (context, lastUpdate, child) {
                // Polling 10sn olduğu için 20sn içinde son güncelleme
                // varsa "CANLI AKIŞ" sayalım. (Ağ yavaşsa esneklik için.)
                final isConnected = lastUpdate != null && DateTime.now().difference(lastUpdate).inSeconds < 20;
                return Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.greenAccent : Colors.orangeAccent, 
                        shape: BoxShape.circle,
                        boxShadow: isConnected ? [
                          BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 5, spreadRadius: 2)
                        ] : []
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'CANLI AKIŞ' : 'BAĞLANTI BEKLENİYOR...',
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500
                      ),
                    ),
                    // Hangi kaynaktan veri geliyor rozeti
                    ValueListenableBuilder<String>(
                      valueListenable: ApiService.sourceNotifier,
                      builder: (_, src, __) {
                        if (src.isEmpty || !isConnected) return const SizedBox.shrink();
                        Color color;
                        switch (src) {
                          case 'Kandilli': color = Colors.tealAccent; break;
                          case 'AFAD': color = Colors.lightBlueAccent; break;
                          case 'Yedek': color = Colors.amberAccent; break;
                          default: color = Colors.redAccent;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: color.withOpacity(0.4), width: 0.5),
                            ),
                            child: Text(
                              src,
                              style: TextStyle(
                                fontSize: 9,
                                color: color,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.medical_services_outlined, size: 20, color: Colors.white),
              tooltip: 'Acil Durum Rehberi',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmergencyMenuPage()),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.5),
              shape: BoxShape.circle
            ),
            child: InkWell(
              onTap: () {
                 // Pass empty list or let MapPage access manager directly.
                 // We will refactor MapPage to use manager, so arg is less relevant.
                 Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const MapPage())
                 );
              },
              child: const Icon(Icons.hub, size: 20, color: Colors.white70),
            ),
          ),
          // Simulation Button

        ],
      ),
      body: ValueListenableBuilder<List<Earthquake>>(
        valueListenable: _manager.earthquakesNotifier,
        builder: (context, earthquakes, child) {
          if (earthquakes.isEmpty) {
             return const Center(child: CircularProgressIndicator());
          }
          
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: earthquakes.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final earthquake = earthquakes[index];
              return _buildEarthquakeCard(context, earthquake);
            },
          );
        },
      ),
    );
  }

  Widget _buildEarthquakeCard(BuildContext context, Earthquake earthquake) {
    final magColor = _getColorForMagnitude(earthquake.magnitude);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DetailPage(earthquake: earthquake)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Magnitude Indicator
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: magColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: magColor.withOpacity(0.5), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      earthquake.magnitude.toStringAsFixed(1),
                      style: TextStyle(
                        color: magColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        earthquake.place,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600, 
                          fontSize: 16,
                          letterSpacing: 0.3
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('HH:mm').format(earthquake.time),
                            style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM').format(earthquake.time),
                            style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Share Button (Replaces Arrow)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle
                  ),
                  child: InkWell(
                    onTap: () {
                      final String message = 
                        "Deprem Bilgisi: ${earthquake.magnitude} büyüklüğünde, ${earthquake.place} konumunda, ${DateFormat('dd.MM.yyyy HH:mm').format(earthquake.time)} tarihinde bir deprem oldu.";
                      Share.share(message);
                    },
                    child: Icon(Icons.share, size: 20, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

