import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/earthquake_model.dart';
import '../services/earthquake_manager.dart';
import 'detail_page.dart';

class MapPage extends StatefulWidget {
  // initialEarthquakes is now optional/redundant if we use manager directly, 
  // but kept for compatibility or pre-loading instant view if desired.
  // Ideally we just check manager.
  final List<Earthquake>? initialEarthquakes;

  const MapPage({super.key, this.initialEarthquakes});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final EarthquakeManager _manager = EarthquakeManager();
  
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // No need for local timer anymore
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  Color _getDepthColor(double depth) {
    if (depth < 5.0) return Colors.red;
    if (depth < 15.0) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deprem Haritası'),
            Text('Sadece son 1 saatteki veriler', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentLocation != null) {
                 _mapController.move(_currentLocation!, 6.0);
              }
            },
          )
        ],
      ),
      body: ValueListenableBuilder<List<Earthquake>>(
        valueListenable: _manager.earthquakesNotifier, 
        builder: (context, earthquakes, child) {
          
          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(39.0, 35.0), // Center of Turkey
              initialZoom: 5.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', 
                userAgentPackageName: 'com.example.earthquake',
              ),
              MarkerLayer(
                markers: [
                  // User Location Marker
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                    ),
                  
                  // Earthquake Markers
                  ...earthquakes.where((eq) {
                    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
                    return eq.time.isAfter(oneHourAgo);
                  }).map((eq) {
                    return Marker(
                      point: LatLng(eq.latitude, eq.longitude),
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => DetailPage(earthquake: eq)),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getDepthColor(eq.depth).withOpacity(0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          );
        }
      ),
    );
  }
}
