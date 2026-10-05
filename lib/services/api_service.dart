import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/earthquake_model.dart';

/// Birden fazla kaynağı sırayla deneyen API servisi.
/// 1. Kandilli resmi sayfa (HTML parse) - EN GÜNCEL kaynak
/// 2. AFAD resmi API - resmi devlet servisi
/// 3. Kandilli wrapper (Orhan Aydoğdu) - 3. parti yedek
class ApiService {
  static const Duration _timeout = Duration(seconds: 10);

  /// Hangi kaynaktan veri geldiği bilgisi (UI'da göstermek için)
  static final ValueNotifier<String> sourceNotifier =
      ValueNotifier<String>('');

  Future<List<Earthquake>> fetchEarthquakes() async {
    Object? lastError;

    // 1. KAYNAK: Kandilli resmi sayfa - en güncel
    try {
      final list = await _fetchFromKandilliOfficial();
      if (list.isNotEmpty) {
        sourceNotifier.value = 'Kandilli';
        return list;
      }
    } catch (e) {
      lastError = e;
      debugPrint('API[Kandilli resmi] başarısız: $e');
    }

    // 2. KAYNAK: AFAD resmi API
    try {
      final list = await _fetchFromAfad();
      if (list.isNotEmpty) {
        sourceNotifier.value = 'AFAD';
        return list;
      }
    } catch (e) {
      lastError = e;
      debugPrint('API[AFAD] başarısız: $e');
    }

    // 3. KAYNAK: Kandilli wrapper (3. parti)
    try {
      final list = await _fetchFromKandilliWrapper();
      if (list.isNotEmpty) {
        sourceNotifier.value = 'Yedek';
        return list;
      }
    } catch (e) {
      lastError = e;
      debugPrint('API[wrapper] başarısız: $e');
    }

    sourceNotifier.value = 'HATA';
    throw Exception('Tüm kaynaklar başarısız: $lastError');
  }

  // ============================================================
  // KAYNAK 1: Kandilli resmi sayfa (HTML parse)
  // URL: http://www.koeri.boun.edu.tr/scripts/lst0.asp
  // En güncel veri burada. HTML monospace tablo, sütun pozisyonlarına
  // göre parse ederiz.
  // ============================================================
  Future<List<Earthquake>> _fetchFromKandilliOfficial() async {
    final uri = Uri.parse('http://www.koeri.boun.edu.tr/scripts/lst0.asp');
    final response = await http.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko)',
      },
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Kandilli HTTP ${response.statusCode}');
    }

    // Kandilli sayfası genelde windows-1254 (Türkçe) veya iso-8859-9.
    // Önce header'dan charset'e bak, yoksa latin1 daha güvenli (Türkçe karakterleri
    // bozmadan okur, çünkü windows-1254 latin1'in üst kümesi gibi davranır
    // ASCII range'inde).
    String body;
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.toLowerCase().contains('utf-8')) {
      body = utf8.decode(response.bodyBytes, allowMalformed: true);
    } else {
      // Default: latin1 ile dene. Türkçe büyük "İ" gibi karakterler
      // doğru görünmeyebilir ama parse için yeterli, sonradan temizleriz.
      body = latin1.decode(response.bodyBytes, allowInvalid: true);
    }

    return _parseKandilliHtml(body);
  }

  /// Kandilli'nin HTML sayfasındaki <pre> bloğunu satır satır parse eder.
  ///
  /// Tablo formatı (sabit kolon pozisyonları):
  /// ```
  /// Tarih      Saat       Enlem(N) Boylam(E) Derinlik(km)  MD ML Mw   Yer
  /// 2026.05.03 00:34:05   38.2323  37.7617      19.9       -.- 1.1 -.- CEVIRME-AKCADAG (MALATYA)            İlksel
  /// ```
  List<Earthquake> _parseKandilliHtml(String html) {
    // <pre>...</pre> bloğunu bul
    final preMatch = RegExp(r'<pre[^>]*>([\s\S]*?)</pre>', caseSensitive: false)
        .firstMatch(html);
    if (preMatch == null) return [];

    final preContent = preMatch.group(1) ?? '';
    final lines = preContent.split('\n');
    final results = <Earthquake>[];

    // Tarih ile başlayan satırlar deprem kayıtları (yyyy.MM.dd)
    final lineRegex = RegExp(r'^\s*(\d{4}\.\d{2}\.\d{2})\s+(\d{2}:\d{2}:\d{2})');

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;
      final m = lineRegex.firstMatch(line);
      if (m == null) continue;

      try {
        // Boşluklara göre tokenize - yer ismi son kısım
        // Tarih Saat Enlem Boylam Derinlik MD ML Mw Yer... ÇözümNiteliği
        final tokens = line.split(RegExp(r'\s+'));
        if (tokens.length < 9) continue;

        final dateStr = tokens[0]; // 2026.05.03
        final timeStr = tokens[1]; // 00:34:05
        final lat = double.tryParse(tokens[2]) ?? 0;
        final lng = double.tryParse(tokens[3]) ?? 0;
        final depth = double.tryParse(tokens[4]) ?? 0;
        // tokens[5]=MD, tokens[6]=ML, tokens[7]=Mw - en yüksek olanı al
        final md = double.tryParse(tokens[5]) ?? 0;
        final ml = double.tryParse(tokens[6]) ?? 0;
        final mw = double.tryParse(tokens[7]) ?? 0;
        final magnitude = [md, ml, mw]
            .where((v) => v > 0)
            .fold<double>(0, (a, b) => b > a ? b : a);

        if (magnitude <= 0) continue;
        if (lat == 0 && lng == 0) continue;

        // Kalan tokens yer + çözüm niteliği. Son token "İlksel" / "REVIZE"
        // gibi bir kelime, onu atla. UTF-8/encoding sorunlarına karşı geniş liste.
        var locationTokens = tokens.sublist(8);
        const tailWords = {
          'İlksel', 'Ilksel', 'ilksel', 'İLKSEL', 'ILKSEL',
          'REVIZE', 'Revize', 'revize', 'REVİZE',
        };
        // Bozuk karakter içeren satır sonunu da temizle (örn. "?lksel", "lksel")
        while (locationTokens.isNotEmpty) {
          final last = locationTokens.last;
          final isTailWord = tailWords.contains(last) ||
              last.toLowerCase().endsWith('lksel') ||
              last.toLowerCase().endsWith('evize');
          if (isTailWord) {
            locationTokens = locationTokens.sublist(0, locationTokens.length - 1);
          } else {
            break;
          }
        }
        var place = locationTokens.join(' ').trim();
        if (place.isEmpty) continue;

        // Son emniyet: yer ismi sonundaki "İlksel"/"Ilksel"/bozuk karakterleri sil
        final cleanRegex = RegExp(
          r'\s*[\?İIı\u00C0-\u00FF\uFFFD]?lksel\s*$|\s*[Rr]evize\s*$',
          caseSensitive: false,
        );
        place = place.replaceAll(cleanRegex, '').trim();
        // Sonda kalan tek harfli/bozuk karakteri de temizle
        place = place.replaceAll(RegExp(r'[\s\?\u00C0-\u00FF\uFFFD]+$'), '').trim();
        if (place.isEmpty) continue;

        // Tarih: 2026.05.03 00:34:05 -> DateTime
        final dateParts = dateStr.split('.');
        final timeParts = timeStr.split(':');
        if (dateParts.length != 3 || timeParts.length != 3) continue;

        final time = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
          int.parse(timeParts[2]),
        );

        final id = 'kandilli_${time.millisecondsSinceEpoch}_${lat}_$lng';

        results.add(Earthquake(
          id: id,
          magnitude: magnitude,
          place: place,
          time: time,
          url: 'http://www.koeri.boun.edu.tr/scripts/lst0.asp',
          depth: depth,
          latitude: lat,
          longitude: lng,
        ));

        if (results.length >= 100) break;
      } catch (e) {
        debugPrint('Kandilli satır parse hatası: $e | satır: $line');
        continue;
      }
    }

    return results;
  }

  // ============================================================
  // KAYNAK 2: AFAD Resmi API
  // ============================================================
  Future<List<Earthquake>> _fetchFromAfad() async {
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(hours: 24));

    String fmt(DateTime d) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)}'
          'T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
    }

    final uri = Uri.parse(
      'https://deprem.afad.gov.tr/apiv2/event/filter'
      '?start=${fmt(start)}&end=${fmt(now)}'
      '&orderby=timedesc&limit=100',
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'Mozilla/5.0 (EarthquakeApp)',
        'Accept': 'application/json',
      },
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('AFAD HTTP ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    if (decoded is! List) throw Exception('AFAD beklenmedik format');

    final list = <Earthquake>[];
    for (final item in decoded.take(100)) {
      if (item is Map<String, dynamic>) {
        final eq = _afadToEarthquake(item);
        if (eq != null) list.add(eq);
      }
    }
    return list;
  }

  Earthquake? _afadToEarthquake(Map<String, dynamic> j) {
    try {
      final magnitude =
          double.tryParse((j['magnitude'] ?? '0').toString()) ?? 0;
      final depth = double.tryParse((j['depth'] ?? '0').toString()) ?? 0;
      final lat = double.tryParse((j['latitude'] ?? '0').toString()) ?? 0;
      final lng = double.tryParse((j['longitude'] ?? '0').toString()) ?? 0;
      final dateStr = (j['date'] ?? '').toString();
      final place = (j['location'] ?? 'Bilinmiyor').toString();
      final id = (j['eventID'] ?? '').toString();

      // AFAD tarihi yerel saat (Türkiye) gibi geliyor (Z yok genelde),
      // örn: "2026-05-02T20:05:04". Olduğu gibi parse et.
      DateTime time;
      try {
        time = DateTime.parse(dateStr);
        if (time.isUtc) time = time.toLocal();
      } catch (_) {
        return null;
      }

      if (magnitude <= 0 || (lat == 0 && lng == 0)) return null;

      return Earthquake(
        id: id.isNotEmpty
            ? 'afad_$id'
            : 'afad_${time.millisecondsSinceEpoch}_${lat}_$lng',
        magnitude: magnitude,
        place: place,
        time: time,
        url: 'https://deprem.afad.gov.tr/last-earthquakes',
        depth: depth,
        latitude: lat,
        longitude: lng,
      );
    } catch (e) {
      debugPrint('AFAD parse: $e');
      return null;
    }
  }

  // ============================================================
  // KAYNAK 3: Kandilli wrapper (3. parti yedek)
  // ============================================================
  Future<List<Earthquake>> _fetchFromKandilliWrapper() async {
    final uri = Uri.parse(
      'https://api.orhanaydogdu.com.tr/deprem/kandilli/live'
      '?t=${DateTime.now().millisecondsSinceEpoch}',
    );
    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'Mozilla/5.0 (EarthquakeApp)',
        'Accept': 'application/json',
      },
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Wrapper HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> data = json.decode(response.body);
    if (data['status'] != true) throw Exception('Wrapper status=false');

    final List<dynamic> result = data['result'] ?? [];
    return result
        .take(100)
        .map((j) => Earthquake.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
