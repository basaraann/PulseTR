import 'package:flutter/material.dart';
import '../../services/emergency_data_service.dart';
import '../../models/emergency_guide_model.dart';
import '../../utils/sos_helper.dart';
import 'guide_detail_page.dart';

import 'whistle_page.dart';
import 'checklist_page.dart';
import 'flashlight_page.dart';

import 'emergency_minimal_page.dart';
import 'mesh_network_page.dart';

class EmergencyMenuPage extends StatelessWidget {
  const EmergencyMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Dark Tactical Theme
      appBar: AppBar(
        title: const Text('HAYATTA KALMA KİTİ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.battery_saver, color: Colors.greenAccent),
            tooltip: 'Güç Tasarrufu Modu',
            onPressed: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(builder: (context) => const EmergencyMinimalPage()),
               );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ALERT SECTION (Red)
            _buildSectionHeader('ACİL DURUM AKSİYON', Colors.redAccent),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildBigActionButton(
                      context, 
                      label: 'SOS\nMESAJI', 
                      icon: Icons.send_and_archive, 
                      color: Colors.red[700]!,
                      onTap: () => _showSosOptions(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBigActionButton(
                       context,
                       label: 'DÜDÜK\nALARM',
                       icon: Icons.campaign, 
                       color: Colors.orange[800]!,
                       onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhistlePage())),
                    ),
                  ),
                ],
              ),
            ),
            
            // TOOLS SECTION (Orange/Yellow)
            _buildSectionHeader('ARAÇLAR', Colors.amber),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                 alignment: WrapAlignment.spaceBetween,
                 spacing: 20,
                 runSpacing: 20,
                 children: [
                   _buildToolButton(context, 'Fener', Icons.flashlight_on, Colors.yellow, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashlightPage()));
                   }),

                   _buildToolButton(context, 'Çanta', Icons.backpack, Colors.green, () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => const ChecklistPage()));
                   }),
                   _buildToolButton(context, 'BLE Ağı', Icons.radar, Colors.blue, () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => const MeshNetworkPage()));
                   }),
                 ],
              ),
            ),

             // GUIDES SECTION (White/Grey)
             const SizedBox(height: 20),
            _buildSectionHeader('BİLGİ REHBERİ', Colors.white70),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                   _buildExpandableGroup(context, 'İLK YARDIM', Icons.medical_services, EmergencyDataService.firstAidGuides),
                   const SizedBox(height: 12),
                   _buildExpandableGroup(context, 'İLETİŞİM BİLGİLERİ', Icons.contact_phone, EmergencyDataService.communicationGuides),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showSosOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('YARDIM ÇAĞRISI GÖNDER', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.blue, size: 32),
              title: const Text('SMS ile Konum Gönder', style: TextStyle(color: Colors.white)),
              tileColor: Colors.grey[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () => SosHelper.sendSosMessage('sms'),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.chat_bubble, color: Colors.green, size: 32),
              title: const Text('WhatsApp ile Konum Gönder', style: TextStyle(color: Colors.white)),
               tileColor: Colors.grey[800],
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               onTap: () => SosHelper.sendSosMessage('whatsapp'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1)),
          Expanded(child: Divider(color: color.withOpacity(0.2), indent: 16)),
        ],
      ),
    );
  }

  Widget _buildBigActionButton(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                label, 
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton(BuildContext context, String label, IconData icon, MaterialColor color, VoidCallback onTap) {
    return Column(
      children: [
        Material(
          color: Colors.grey[800],
          shape: CircleBorder(side: BorderSide(color: color.shade700, width: 2)),
          child: InkWell(
            onTap: onTap,
             customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, size: 28, color: color.shade400),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildExpandableGroup(BuildContext context, String title, IconData icon, List<GuideItem> items) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        collapsedBackgroundColor: Colors.grey[800],
        backgroundColor: Colors.grey[800],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        children: items.map((guide) => Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[700]!))
          ),
          child: ListTile(
            title: Text(guide.title, style: const TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white30),
            onTap: () {
               Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GuideDetailPage(guideItem: guide),
                ),
              );
            },
          ),
        )).toList(),
      ),
    );
  }
}
