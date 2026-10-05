import 'package:flutter/material.dart';
import 'profile_setup_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Anlık Deprem Takibi',
      'desc': 'Türkiye ve çevresindeki depremleri anlık olarak harita üzerinde görüntüleyin ve bildirim alın.',
      'icon': Icons.public,
      'color': Colors.blue[400],
    },
    {
      'title': 'Hayatta Kalma Kiti',
      'desc': 'Fener, Düdük, SOS Mesajı ve Deprem Çantası gibi hayati araçlara internetsiz erişin.',
      'icon': Icons.medical_services,
      'color': Colors.red[400],
    },
    {
      'title': 'Çevrimdışı Güvenlik',
      'desc': 'İnternet olmasa bile BLE Mesh ağı ve offline rehberler ile güvende kalın.',
      'icon': Icons.offline_bolt,
      'color': Colors.green[400],
    },
  ];

  void _finishOnboarding() async {
    // Akış: Onboarding -> Profil -> Bildirim Ayarları -> Home
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // App standard dark bg
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final item = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: (item['color'] as Color).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item['icon'], size: 80, color: item['color']),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          item['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          item['desc'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Indicators & Button
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? Colors.blue : Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 40),
                  
                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                         if (_currentPage < _pages.length - 1) {
                           _controller.nextPage(
                             duration: const Duration(milliseconds: 300), 
                             curve: Curves.easeIn
                           );
                         } else {
                           _finishOnboarding();
                         }
                      },
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'BAŞLAYALIM 🚀' : 'İLERLE',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
