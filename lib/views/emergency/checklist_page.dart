import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  final List<String> _items = [
    'Su (Kişi başı en az 4 litre)',
    'Konserve / Kuru Gıda (3 günlük)',
    'İlk Yardım Çantası',
    'Pilli Radyo ve Yedek Piller',
    'El Feneri',
    'Düdük',
    'Toz Maskesi',
    'Önemli Evrak Kopyaları (Kimlik, Tapu vs.)',
    'Nakit Para',
    'Kibrit / Çakmak',
    'Hijyen Malzemeleri & Islak Mendil',
    'Battaniye / Uyku Tulumu',
    'Yedek Kıyafet',
    'Powerbank (Şarj edilmiş)',
  ];

  // Store check state by item index
  List<bool> _checked = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    // Initialize list with false
    List<bool> loaded = List.filled(_items.length, false);
    
    // Load saved states
    for (int i = 0; i < _items.length; i++) {
       loaded[i] = prefs.getBool('checklist_$i') ?? false;
    }

    setState(() {
      _checked = loaded;
      _isLoading = false;
    });
  }

  Future<void> _toggleItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _checked[index] = !_checked[index];
    });
    await prefs.setBool('checklist_$index', _checked[index]);
  }

  double _calculateProgress() {
    if (_checked.isEmpty) return 0.0;
    int count = _checked.where((c) => c).length;
    return count / _checked.length;
  }

  @override
  Widget build(BuildContext context) {
    // Green theme for preparation
    final double progress = _isLoading ? 0 : _calculateProgress();
    final int percent = (progress * 100).toInt();

    return Scaffold(
      backgroundColor: Colors.white, // Force Light Theme (Paper look)
      appBar: AppBar(
        title: const Text('Deprem Çantası'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
          children: [
            // Header Progress
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.green[50], // Light Green bg
              child: Column(
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text('Hazırlık Durumu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[900])),
                       Text('%$percent Tamamlandı', style: TextStyle(fontSize: 16, color: Colors.green[900], fontWeight: FontWeight.bold)),
                     ],
                   ),
                   const SizedBox(height: 10),
                   LinearProgressIndicator(
                     value: progress,
                     minHeight: 12,
                     backgroundColor: Colors.green[100],
                     valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
                     borderRadius: BorderRadius.circular(6),
                   ),
                   const SizedBox(height: 10),
                   const Text(
                     'Bu liste AFAD önerilerine göre hazırlanmıştır. Eksiklerinizi tamamlayın.',
                     style: TextStyle(fontSize: 12, color: Colors.grey),
                   )
                ],
              ),
            ),
            
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final isChecked = _checked[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: Checkbox(
                      value: isChecked,
                      activeColor: Colors.green[700],
                      onChanged: (val) => _toggleItem(index),
                    ),
                    title: Text(
                      _items[index],
                      style: TextStyle(
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked ? Colors.grey : Colors.black87,
                      ),
                    ),
                    onTap: () => _toggleItem(index),
                  );
                },
              ),
            ),
          ],
        ),
    );
  }
}
