import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/sos_helper.dart';

class EmergencyMinimalPage extends StatelessWidget {
  const EmergencyMinimalPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Pure Black Background for OLED Energy Saving
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // HEADER
              const Column(
                children: [
                   Icon(Icons.battery_saver, color: Colors.green, size: 30),
                   SizedBox(height: 8),
                   Text(
                     'ENERJİ TASARRUFU MODU',
                     style: TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 12),
                   ),
                ],
              ),
              
              // MAIN QUICK ACTIONS
              Column(
                children: [
                   _buildBigButton(
                     context,
                     label: 'YARDIM LAZIM',
                     icon: Icons.sos,
                     color: Colors.red,
                     onTap: () => SosHelper.sendSosMessage('sms'),
                   ),
                   const SizedBox(height: 30),
                   _buildBigButton(
                     context,
                     label: 'İYİYİM / GÜVENDEYİM',
                     icon: Icons.check_circle,
                     color: Colors.green,
                     onTap: () => _sendSafeMessage(),
                   ),
                ],
              ),

              // EXIT
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.exit_to_app, color: Colors.grey),
                label: const Text('NORMAL MODA DÖN', style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigButton(BuildContext context, {required String label, required IconData icon, required MaterialColor color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 160,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color, // The most visible part
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0, // No shadow processing
        ),
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _sendSafeMessage() async {
    const String message = "DURUM RAPORU: Ben iyiyim, güvendeyim. Şarjımı korumak için telefonu kapatıyorum.";
    // Simple SMS trigger
    final Uri url = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
