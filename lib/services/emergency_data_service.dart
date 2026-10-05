import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/emergency_guide_model.dart';

class EmergencyDataService {
  
  static final List<GuideItem> firstAidGuides = [
    GuideItem(
      title: 'Kanamalar',
      icon: Icons.bloodtype,
      content: 'Kanama kontrolü hayati önem taşır.',
      steps: [
        GuideStep(
           title: 'Durumu Değerlendir',
           description: 'Kendi güvenliğinizi sağlayın. Yaralının bilincini ve solunumunu (ABC) kontrol edin.',
           icon: Icons.visibility,
        ),
        GuideStep(
           title: 'Baskı Uygula',
           description: 'Kanayan bölgeye temiz bir bezle doğrudan ve güçlü baskı uygulayın.',
           icon: Icons.back_hand,
        ),
        GuideStep(
           title: 'İkinci Bezi Koy',
           description: 'Kanama durmazsa, ilk bezi kaldırmadan üzerine ikinci bir bez koyarak baskıya devam edin.',
           icon: Icons.layers,
        ),
        GuideStep(
           title: 'Turnike (Gerekirse)',
           description: 'Sadece uzuv kopması veya durdurulamayan fışkıran kanama varsa, kanama yerinin 5-10 cm üzerinden turnike uygulayın.',
           icon: Icons.dangerous,
        ),
        GuideStep(
           title: 'Şok Pozisyonu',
           description: 'Yaralıyı sırtüstü yatırın ve ayaklarını 30 cm (kalp seviyesinin üzeri) kaldırın (baş/boyun travması yoksa).',
           icon: Icons.airline_seat_flat,
        ),
      ]
    ),
    GuideItem(
      title: 'Kırık ve Çıkıklar',
      icon: Icons.personal_injury,
      content: 'Hareketsizlik esastır.',
      steps: [
        GuideStep(
           title: 'Hareket Ettirme',
           description: 'Yaralı bölgeyi asla hareket ettirmeyin. "Düzeltmeye" çalışmayın.',
           icon: Icons.do_not_touch,
        ),
        GuideStep(
           title: 'Atelle Sabitle',
           description: 'Kırık bölgeyi içine alacak şekilde sert bir cisimle (tahta, karton) sabitleyin.',
           icon: Icons.build,
        ),
        GuideStep(
           title: 'Açık Kırık Varsa',
           description: 'Yara üzerini temiz bir bezle kapatın. Kemik parçalarına dokunmayın.',
           icon: Icons.healing,
        ),
        GuideStep(
           title: 'Soğuk Uygulama',
           description: 'Şişliği azaltmak için bez üzerinden soğuk uygulayın (buz doğrudan cilde temas etmemeli).',
           icon: Icons.ac_unit,
        ),
      ]
    ),
    GuideItem(
      title: 'Enkaz Altında',
      icon: Icons.foundation,
      content: 'Enerjinizi korumak en önemli kuraldır.',
      steps: [
        GuideStep(
           title: 'Sakin Ol',
           description: 'Panik yapmak oksijen tüketimini artırır. Sakin kalmaya çalışın.',
           icon: Icons.self_improvement,
        ),
        GuideStep(
           title: 'Ses Verme',
           description: 'Enerjinizi koruyun. Sadece dışarıdan ses duyduğunuzda karşılık verin.',
           icon: Icons.volume_up,
        ),
        GuideStep(
           title: 'Tozdan Korun',
           description: 'Ağzınızı ve burnunuzu kıyafetinizle veya bir bezle kapatın. Toz yutmamaya çalışın.',
           icon: Icons.masks,
        ),
        GuideStep(
           title: 'Sinyal Ver',
           description: 'Bağırmak yerine bir metale veya duvara sert bir cisimle vurarak ses çıkarın.',
           icon: Icons.notifications_active,
        ),
      ]
    ),
     GuideItem(
      title: 'Yanıklar',
      icon: Icons.fire_extinguisher,
      content: 'Yanığı soğutmak ilk müdahaledir.',
      steps: [
        GuideStep(
           title: 'Soğut',
           description: 'Yanık bölgeyi en az 20 dakika tazyiksiz akan soğuk suyun altında tutun.',
           icon: Icons.water_drop,
        ),
        GuideStep(
           title: 'Yabancı Madde Sürme',
           description: 'Diş macunu, yoğurt, salça gibi maddeler ASLA sürmeyin.',
           icon: Icons.block,
        ),
        GuideStep(
           title: 'Temiz Kapat',
           description: 'Su toplamış yerleri patlatmayın. Yanık üzerini temiz, nemli bir bezle gevşekçe örtün.',
           icon: Icons.medical_services,
        ),
      ]
    ),
  ];

  static final List<GuideItem> communicationGuides = [
     GuideItem(
      title: 'Acil Numaralar',
      icon: Icons.phone_in_talk,
      content: '112 Tek Acil Çağrı Numarasıdır.',
      steps: [
        GuideStep(
           title: '112 - Acil Çağrı',
           description: 'Ambulans, Polis, Jandarma, İtfaiye ve AFAD için tek numara: 112.',
           icon: Icons.call,
        ),
        GuideStep(
           title: '184 - SABİM',
           description: 'Sağlık Bakanlığı İletişim Merkezi.',
           icon: Icons.local_hospital,
        ),
        GuideStep(
           title: 'ALO 122 - AFAD',
           description: 'Afet ve Acil Durum Yönetimi Başkanlığı (Genellikle 112 ye yönlendirilir).',
           icon: Icons.warning,
        ),
      ]
    ),
    GuideItem(
      title: 'İletişim Önerileri',
      icon: Icons.chat,
      content: 'Hatları meşgul etmeyin.',
      steps: [
        GuideStep(
           title: 'SMS Kullanın',
           description: 'Aramak yerine SMS veya internet tabanlı mesajlaşma (WhatsApp) kullanın. Deprem anında sesli aramalar şebekeyi kilitler.',
           icon: Icons.sms,
        ),
        GuideStep(
           title: 'Konum Paylaş',
           description: 'Durumunuzu bildirirken mutlaka konumunuzu da paylaşın.',
           icon: Icons.location_on,
        ),
        GuideStep(
           title: '"Güvendeyim" Uygulamaları',
           description: 'Operatörlerin veya AFADın "Güvendeyim" uygulamalarını önceden yükleyin.',
           icon: Icons.app_shortcut,
        ),
      ]
    ),
  ];

  // List will be populated from JSON
  static List<AssemblyPoint> assemblyPoints = [];

  Future<void> loadAssemblyPoints() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/assembly_points.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      assemblyPoints = jsonList.map((json) {
        return AssemblyPoint(
          id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: json['name'],
          description: json['description'],
          latitude: (json['latitude'] as num).toDouble(),
          longitude: (json['longitude'] as num).toDouble(),
        );
      }).toList();
      
      print("Loaded [${assemblyPoints.length}] assembly points from JSON.");
    } catch (e) {
      print("Error loading assembly points: $e");
    }
  }

  AssemblyPoint? findNearestAssemblyPoint(double userLat, double userLng, {double? maxDistance}) {
    if (assemblyPoints.isEmpty) return null;

    final Distance distance = Distance();
    AssemblyPoint? nearest; // Changed to nullable
    double minDistance = double.infinity;

    for (var point in assemblyPoints) {
      final double d = distance.as(LengthUnit.Meter, LatLng(userLat, userLng), LatLng(point.latitude, point.longitude));
      
      // If found a closer point
      if (d < minDistance) {
        // Check if it respects the maxDistance constraint (if provided)
        if (maxDistance == null || d <= maxDistance) {
            minDistance = d;
            nearest = point;
        }
      }
    }
    
    return nearest;
  }
}
