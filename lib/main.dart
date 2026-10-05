import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/background_service.dart';
import 'views/home_page.dart';
import 'views/intro/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Background service initialization moved to initState to prevent blocking startup

  runApp(const EarthquakeApp());
}


class EarthquakeApp extends StatefulWidget {
  const EarthquakeApp({super.key});

  @override
  State<EarthquakeApp> createState() => _EarthquakeAppState();
}

class _EarthquakeAppState extends State<EarthquakeApp> {
  bool? _seenOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    _requestPermissions();
    _initService();
  }

  Future<void> _initService() async {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
         final backgroundService = BackgroundService();
         await backgroundService.initialize();
         // backgroundService.registerPeriodicTask(); // Not needed for flutter_background_service usually
      } catch (e) {
        debugPrint("Service init failed: $e");
      }
    }
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    });
  }

  Future<void> _requestPermissions() async {
    // Bildirim izni
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      title: 'Earthquake Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        primaryColor: const Color(0xFF38BDF8), // Sky 400
        cardColor: const Color(0xFF1E293B), // Slate 800
        
        // Font
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold, 
            color: Colors.white,
            letterSpacing: 0.5
          )
        ),
        
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
      ),
      home: _seenOnboarding == null 
          ? const Center(child: CircularProgressIndicator()) // Waiting for prefs
          : (_seenOnboarding! ? const HomePage() : const OnboardingPage()),
    );
  }
}

