import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/earthquake_model.dart'; // import added

class DetailPage extends StatelessWidget {
  final Earthquake earthquake;

  const DetailPage({super.key, required this.earthquake});

  Future<void> _launchURL() async {
    final Uri url = Uri.parse(earthquake.url);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine colors
    final magColor = _getAlertColor(earthquake.magnitude);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Deprem Detayı'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header / Map View
            SizedBox(
              height: 350,
              width: double.infinity,
              child: Stack(
                children: [
                   // Map
                   FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(earthquake.latitude, earthquake.longitude),
                        initialZoom: 7.0, // Zoom in to show context
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.earthquake',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(earthquake.latitude, earthquake.longitude),
                              width: 50,
                              height: 50,
                              child: _buildPulsingMarker(magColor),
                            ),
                          ],
                        ),
                      ],
                   ),
                  
                  // Gradient Overlay (to blend with body)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).scaffoldBackgroundColor.withOpacity(0),
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Back Button (re-added here to ensure visibility over map)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            earthquake.place,
                            style: const TextStyle(
                              fontSize: 26, 
                              fontWeight: FontWeight.bold, 
                              height: 1.2
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildBadge(
                          context, 
                          "${earthquake.magnitude.toStringAsFixed(1)} Büyüklük", 
                          magColor
                        ),
                        const SizedBox(width: 12),
                        _buildBadge(
                          context, 
                          "${earthquake.depth} km Derinlik", 
                          Colors.blue
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Info Cards
                    _buildInfoCard(
                      context,
                      icon: Icons.calendar_today_rounded,
                      title: "Tarih & Saat",
                      value: DateFormat('dd MMMM yyyy\nHH:mm:ss').format(earthquake.time),
                    ),
                    const SizedBox(height: 16),
                     _buildInfoCard(
                      context,
                      icon: Icons.fingerprint,
                      title: "Olay ID",
                      value: earthquake.id,
                      isMono: true,
                    ),

                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                        ),
                        onPressed: _launchURL,
                        icon: const Icon(Icons.public),
                        label: const Text("Kandilli Kaydını Aç", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required IconData icon, required String title, required String value, bool isMono = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05))
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle
            ),
            child: Icon(icon, color: Colors.grey[400]),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                value, 
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w600,
                  fontFamily: isMono ? 'Courier New' : null,
                  letterSpacing: isMono ? -0.5 : 0
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Color _getAlertColor(double mag) {
    if (mag < 3.0) return const Color(0xFF4ADE80);
    if (mag < 5.0) return const Color(0xFFFACC15);
    if (mag < 7.0) return const Color(0xFFFB923C);
    return const Color(0xFFF87171);
  }

  Widget _buildPulsingMarker(Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.3),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2)
          ),
        ),
      ],
    );
  }
}
