import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home_page.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  double _minMagnitude = 3.0; // Default
  double _maxDistance = 500.0; // Km
  bool _notifyAllSignificant = true; // > 4.0 always

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _minMagnitude = prefs.getDouble('pref_min_magnitude') ?? 3.0;
      _maxDistance = prefs.getDouble('pref_max_distance') ?? 500.0;
    });
  }

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pref_min_magnitude', _minMagnitude);
    await prefs.setDouble('pref_max_distance', _maxDistance);
    await prefs.setBool('pref_notify_all_significant', _notifyAllSignificant);
    // Mark onboarding seen here if not already
    await prefs.setBool('seen_onboarding', true);

    if (mounted) {
      // Return to Home (which pushed this page)
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
         Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Bildirim Ayarları'),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false, // Force flow
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sizi Nasıl Uyaralım?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                'Konumunuza ve deprem büyüklüğüne göre bildirim tercihlerinizi belirleyin.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // 1. Magnitude Slider
              const Text(
                'Minimum Büyüklük',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueAccent),
              ),
              const SizedBox(height: 8),
              Text(
                '${_minMagnitude.toStringAsFixed(1)} ve üzeri',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Slider(
                value: _minMagnitude,
                min: 1.0,
                max: 7.0,
                divisions: 60, // 0.1 steps
                label: _minMagnitude.toStringAsFixed(1),
                onChanged: (val) => setState(() => _minMagnitude = val),
              ),
              const SizedBox(height: 30),

              // 2. Distance Slider
              const Text(
                'Maksimum Uzaklık (Sizin Konumunuz)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.greenAccent),
              ),
              const SizedBox(height: 8),
              Text(
                '${_maxDistance.toInt()} km içerisindeki depremler',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Slider(
                value: _maxDistance,
                min: 10,
                max: 2000,
                divisions: 199, 
                label: "${_maxDistance.toInt()} km",
                onChanged: (val) => setState(() => _maxDistance = val),
              ),
              const SizedBox(height: 30),

              // 3. Override Removed (Strict Logic Enforced)
              // User settings (Mag & Dist) are now the only truth.
              const Text(
                'Bilgilendirme',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bildirimler sadece yukarıda seçtiğiniz Büyüklük ve Mesafe kriterlerine TAMI TAMINA uyduğunda gönderilecektir.',
                style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _saveAndContinue,
                  child: const Text(
                    'AYARLARI KAYDET VE BAŞLA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
