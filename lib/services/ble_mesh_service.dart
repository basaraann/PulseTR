import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'user_profile_service.dart';

/// Mesh Mesaj Tipleri (advertise paketinde 1 byte)
enum MeshMsgType {
  presence(0x01),  // Sadece "buradayım" - normal yayın
  sos(0x02),       // Yardım istiyorum
  safe(0x03),      // İyiyim, güvendeyim
  needHelp(0x04);  // Şu konuda yardım lazım

  final int code;
  const MeshMsgType(this.code);

  static MeshMsgType fromCode(int code) {
    return MeshMsgType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => MeshMsgType.presence,
    );
  }

  String get label {
    switch (this) {
      case MeshMsgType.presence: return 'Yakında';
      case MeshMsgType.sos: return 'SOS';
      case MeshMsgType.safe: return 'Güvende';
      case MeshMsgType.needHelp: return 'Yardım İstiyor';
    }
  }
}

/// Mesh ağındaki bir kullanıcı
class MeshNode {
  final String id;            // BLE remoteId
  final String name;          // "Ahmet Y."
  final String bloodType;     // "A+", "0-" - bilinmiyorsa "?"
  final int rssi;
  final double distanceMeters;   // RSSI'dan tahmin
  final double? gpsDistanceMeters; // GPS varsa daha doğru
  final double? bearingDegrees;    // GPS varsa azimut (0=Kuzey)
  final double? latitude;
  final double? longitude;
  final MeshMsgType messageType;
  final DateTime lastSeen;

  MeshNode({
    required this.id,
    required this.name,
    required this.bloodType,
    required this.rssi,
    required this.distanceMeters,
    required this.messageType,
    required this.lastSeen,
    this.gpsDistanceMeters,
    this.bearingDegrees,
    this.latitude,
    this.longitude,
  });

  /// "12.4m KD" gibi okunabilir yön/mesafe metni
  String get directionText {
    final dist = gpsDistanceMeters ?? distanceMeters;
    final distStr = dist < 10
        ? '${dist.toStringAsFixed(1)}m'
        : '${dist.toStringAsFixed(0)}m';
    if (bearingDegrees == null) return distStr;
    return '$distStr ${_compassPoint(bearingDegrees!)}';
  }

  bool get hasGps => latitude != null && longitude != null;
  bool get isAlerting =>
      messageType == MeshMsgType.sos || messageType == MeshMsgType.needHelp;
}

String _compassPoint(double degrees) {
  // 0=K, 90=D, 180=G, 270=B
  final d = (degrees % 360 + 360) % 360;
  const points = ['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
  final idx = ((d + 22.5) / 45).floor() % 8;
  return points[idx];
}

/// BLE Advertise paketinin ham veri yapısı.
///
/// Manufacturer Data (max ~24 byte payload):
/// [0]    : protokol versiyonu (0x01)
/// [1]    : mesaj tipi
/// [2]    : kan grubu kodu (0=?, 1=A+, 2=A-, 3=B+, 4=B-, 5=AB+, 6=AB-, 7=0+, 8=0-)
/// [3]    : GPS var mı? (0/1)
/// [4-7]  : latitude (int32, derece * 1e6, signed)
/// [8-11] : longitude (int32, derece * 1e6, signed)
/// [12]   : isim uzunluğu
/// [13..] : isim (UTF-8, max 11 byte)
class _MeshPayload {
  static const int protocolVersion = 0x01;

  /// localName text protokolü prefix'i - iOS yayın formatını ayırt etmek için
  /// Format: "EQ|<msgChar>|<bloodCode>|<lat>,<lng>|<name>"
  /// Örn:    "EQ|S|7|41.012,28.978|Ahmet Y."
  static const String textPrefix = 'EQ|';

  static int bloodCode(String bloodType) {
    switch (bloodType) {
      case 'A+': return 1;
      case 'A-': return 2;
      case 'B+': return 3;
      case 'B-': return 4;
      case 'AB+': return 5;
      case 'AB-': return 6;
      case '0+': return 7;
      case '0-': return 8;
      default: return 0;
    }
  }

  static String bloodFromCode(int code) {
    const map = {
      1: 'A+', 2: 'A-', 3: 'B+', 4: 'B-',
      5: 'AB+', 6: 'AB-', 7: '0+', 8: '0-',
    };
    return map[code] ?? '?';
  }

  static Uint8List encode({
    required MeshMsgType msgType,
    required String bloodType,
    required String name,
    double? lat,
    double? lng,
  }) {
    final builder = BytesBuilder();
    builder.addByte(protocolVersion);
    builder.addByte(msgType.code);
    builder.addByte(bloodCode(bloodType));

    final hasGps = (lat != null && lng != null) ? 1 : 0;
    builder.addByte(hasGps);

    final latInt = ((lat ?? 0.0) * 1e6).round();
    final lngInt = ((lng ?? 0.0) * 1e6).round();
    final coord = ByteData(8);
    coord.setInt32(0, latInt, Endian.little);
    coord.setInt32(4, lngInt, Endian.little);
    builder.add(coord.buffer.asUint8List());

    // İsim - 11 byte limit (UTF-8). Türkçe karakter bozulmasın diye
    // çok-baytlı karakterleri ortadan bölmemeye dikkat ederiz.
    final nameBytes = _safeUtf8Truncate(name, 11);
    builder.addByte(nameBytes.length);
    builder.add(nameBytes);

    return builder.toBytes();
  }

  /// String'i UTF-8'e çevirip belirtilen byte sayısına güvenli kırp.
  /// Çok-baytlı karakterleri bozmaz.
  static Uint8List _safeUtf8Truncate(String s, int maxBytes) {
    final all = utf8.encode(s);
    if (all.length <= maxBytes) return Uint8List.fromList(all);
    // Geri sar, continuation byte'ı (10xxxxxx) ortada bırakma
    var cut = maxBytes;
    while (cut > 0 && (all[cut] & 0xC0) == 0x80) {
      cut--;
    }
    return Uint8List.fromList(all.sublist(0, cut));
  }

  static _DecodedPayload? decode(Uint8List data) {
    try {
      if (data.length < 13) return null;
      if (data[0] != protocolVersion) return null;

      final msgType = MeshMsgType.fromCode(data[1]);
      final bloodType = bloodFromCode(data[2]);
      final hasGps = data[3] == 1;

      final byteData = ByteData.sublistView(data, 4, 12);
      final latInt = byteData.getInt32(0, Endian.little);
      final lngInt = byteData.getInt32(4, Endian.little);
      final lat = hasGps ? latInt / 1e6 : null;
      final lng = hasGps ? lngInt / 1e6 : null;

      final nameLen = data[12];
      String name = '';
      if (nameLen > 0 && 13 + nameLen <= data.length) {
        try {
          name = utf8.decode(data.sublist(13, 13 + nameLen),
              allowMalformed: true);
        } catch (_) {
          name = '';
        }
      }

      return _DecodedPayload(
        msgType: msgType,
        bloodType: bloodType,
        name: name,
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      return null;
    }
  }

  // ========================================================
  // TEXT PROTOKOL - iOS için (localName içinde)
  // Format: "EQ|<msgChar>|<bloodCode>|<lat>,<lng>|<name>"
  // Örnek:  "EQ|S|7|41.012,28.978|Ahmet Y."
  // GPS yoksa: "EQ|P|7||Ahmet Y."
  // ========================================================

  static String _msgChar(MeshMsgType t) {
    switch (t) {
      case MeshMsgType.presence: return 'P';
      case MeshMsgType.sos: return 'S';
      case MeshMsgType.safe: return 'F';
      case MeshMsgType.needHelp: return 'H';
    }
  }

  static MeshMsgType _msgFromChar(String c) {
    switch (c) {
      case 'S': return MeshMsgType.sos;
      case 'F': return MeshMsgType.safe;
      case 'H': return MeshMsgType.needHelp;
      case 'P':
      default:  return MeshMsgType.presence;
    }
  }

  /// Text formatında advert localName üretir. iOS için ana kanal.
  /// localName tüm BLE adv. paketinde ~28 byte. Korumalı sınır kullanırız.
  static String encodeText({
    required MeshMsgType msgType,
    required String bloodType,
    required String name,
    double? lat,
    double? lng,
  }) {
    final msg = _msgChar(msgType);
    final blood = bloodCode(bloodType).toString();
    final loc = (lat != null && lng != null)
        ? '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}'
        : '';
    // 28 byte sınırı (iOS): "EQ|X|N|LL.LLL,EE.EEE|" = 21 byte sabit + isim
    // İsim için ~7 byte kalıyor — onu güvenli kırp.
    var safeName = name;
    final fixedPart = '$textPrefix$msg|$blood|$loc|';
    final remaining = 28 - fixedPart.length;
    if (remaining > 0 && utf8.encode(safeName).length > remaining) {
      safeName = String.fromCharCodes(
        _safeUtf8Truncate(safeName, remaining),
      );
    } else if (remaining <= 0) {
      safeName = '';
    }
    return '$fixedPart$safeName';
  }

  /// Text formatlı localName'i parse eder. "EQ|" ile başlamayan reddedilir.
  static _DecodedPayload? decodeText(String localName) {
    try {
      if (!localName.startsWith(textPrefix)) return null;
      final body = localName.substring(textPrefix.length);
      final parts = body.split('|');
      if (parts.length < 4) return null;

      final msgType = _msgFromChar(parts[0]);
      final bloodTypeCode = int.tryParse(parts[1]) ?? 0;
      final bloodType = bloodFromCode(bloodTypeCode);

      double? lat;
      double? lng;
      if (parts[2].isNotEmpty && parts[2].contains(',')) {
        final coords = parts[2].split(',');
        if (coords.length == 2) {
          lat = double.tryParse(coords[0]);
          lng = double.tryParse(coords[1]);
        }
      }

      // İsim kısmı (kalan tüm parçaları birleştir, isim içinde | olabilir
      // diye ihtiyat). Normalde tek parça.
      final name = parts.sublist(3).join('|');

      return _DecodedPayload(
        msgType: msgType,
        bloodType: bloodType,
        name: name,
        lat: lat,
        lng: lng,
      );
    } catch (_) {
      return null;
    }
  }
}

class _DecodedPayload {
  final MeshMsgType msgType;
  final String bloodType;
  final String name;
  final double? lat;
  final double? lng;

  _DecodedPayload({
    required this.msgType,
    required this.bloodType,
    required this.name,
    this.lat,
    this.lng,
  });
}

class BleMeshService {
  static final BleMeshService _instance = BleMeshService._internal();
  factory BleMeshService() => _instance;
  BleMeshService._internal();

  // Manufacturer ID - Android binary protokolü için (iOS bunu görmezden gelir)
  static const int _manufacturerId = 0xFFFE;

  // Service UUID - iOS için ZORUNLU. Hem Android hem iOS bu UUID'yi yayınlar
  // ve sadece bu UUID'yi yayınlayan cihazları "bizim app kullanıcısı" olarak
  // tanır. Sabit değer; uygulama versiyonları arasında değiştirme.
  static const String meshServiceUuid = 'a7eaf4c0-6e3d-4b8a-9f01-d5e2c8b9a0f1';

  final _profileService = UserProfileService();
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  final StreamController<List<MeshNode>> _nodesController =
      StreamController<List<MeshNode>>.broadcast();
  Stream<List<MeshNode>> get nodesStream => _nodesController.stream;

  final ValueNotifier<String> statusNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> isBroadcastingNotifier = ValueNotifier<bool>(false);

  final Map<String, MeshNode> _foundNodes = {};

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _staleCleanupTimer;
  Timer? _broadcastRefreshTimer;

  Position? _currentPosition;
  double? _currentHeading; // cihazın baktığı yön (derece, 0=Kuzey)
  MeshMsgType _currentMsgType = MeshMsgType.presence;

  bool _isScanning = false;
  bool _isBroadcasting = false;

  // -------- KAMU API --------

  Future<void> startScan() async {
    if (_isScanning) return;

    _foundNodes.clear();
    _emit();

    if (kIsWeb || Platform.isWindows || Platform.isLinux) {
      statusNotifier.value = 'Bu platformda BLE desteklenmiyor';
      _startSimulation();
      return;
    }

    final permsOk = await _checkPermissions();
    if (!permsOk) return;

    if (!await FlutterBluePlus.isSupported) {
      statusNotifier.value = 'Bluetooth desteklenmiyor';
      return;
    }

    if (Platform.isAndroid &&
        FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {}
    }

    _isScanning = true;
    statusNotifier.value = 'Yakındaki kullanıcılar aranıyor...';

    // GPS ve pusula dinlemesi
    await _startLocationTracking();

    // Sürekli tarama (timeout=0 means continuous on Android)
    try {
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        androidUsesFineLocation: true,
      );
      debugPrint('BLE Scan başladı (continuousUpdates=true)');
    } catch (e) {
      debugPrint('BLE startScan hatası: $e');
    }

    _scanSub = FlutterBluePlus.scanResults.listen(
      (results) {
        // Debug: Kaç cihaz görülüyor, kaç tanesi bizim app
        if (results.isNotEmpty) {
          final ourApp = results.where((r) {
            final hasManufacturer =
                r.advertisementData.manufacturerData[_manufacturerId] != null;
            final hasName = r.advertisementData.advName
                .startsWith(_MeshPayload.textPrefix);
            final hasUuid = r.advertisementData.serviceUuids.any((u) =>
                u.str.toLowerCase() == meshServiceUuid.toLowerCase());
            return hasManufacturer || hasName || hasUuid;
          }).length;
          if (ourApp > 0) {
            debugPrint(
                'BLE: ${results.length} cihaz görülüyor, $ourApp tanesi bizim app');
          }
        }
        _processScanResults(results);
      },
      onError: (e) => debugPrint('Scan stream error: $e'),
    );

    // Eski/kaybolan node'ları temizleme
    _staleCleanupTimer?.cancel();
    _staleCleanupTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cleanupStaleNodes(),
    );
  }

  Future<void> stopScan() async {
    _isScanning = false;
    await _scanSub?.cancel();
    _scanSub = null;
    _staleCleanupTimer?.cancel();
    _positionSub?.cancel();
    _positionSub = null;
    _compassSub?.cancel();
    _compassSub = null;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
    _simTimer?.cancel();
  }

  /// Yayını başlatır. msgType ile ne durumda olduğunu belirtir.
  Future<void> startBroadcast({
    MeshMsgType msgType = MeshMsgType.presence,
  }) async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) {
      statusNotifier.value = 'Bu platformda yayın desteklenmiyor';
      return;
    }

    _currentMsgType = msgType;

    // Android'de bluetoothAdvertise izni gerek; iOS'ta sistem otomatik sorar.
    if (Platform.isAndroid) {
      final granted = await Permission.bluetoothAdvertise.request().isGranted;
      if (!granted) {
        statusNotifier.value = 'Bluetooth Yayın izni reddedildi';
        return;
      }
    }

    await _doBroadcast();

    // Advertise paketi 30 saniyede bir kendini yenilesin (GPS güncellensin)
    _broadcastRefreshTimer?.cancel();
    _broadcastRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (_isBroadcasting) await _doBroadcast();
      },
    );
  }

  Future<void> stopBroadcast() async {
    _isBroadcasting = false;
    isBroadcastingNotifier.value = false;
    _broadcastRefreshTimer?.cancel();
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;
    try {
      await _peripheral.stop();
    } catch (e) {
      debugPrint('Stop broadcast error: $e');
    }
  }

  /// Mesaj tipini değiştir (örn. SOS bas) ve yeniden yayınla
  Future<void> updateBroadcastMessage(MeshMsgType msgType) async {
    _currentMsgType = msgType;
    if (_isBroadcasting) {
      await _doBroadcast();
    }
  }

  void dispose() {
    stopScan();
    stopBroadcast();
    _nodesController.close();
  }

  // -------- İÇ MANTIK --------

  Future<void> _doBroadcast() async {
    final profile = _profileService.current ?? await _profileService.load();
    if (!profile.isComplete) {
      statusNotifier.value = 'Profil tamamlanmamış';
      return;
    }

    // Binary payload - Android'den Android'e en verimli yol
    final binaryPayload = _MeshPayload.encode(
      msgType: _currentMsgType,
      bloodType: profile.bloodType,
      name: profile.bleDisplayName,
      lat: _currentPosition?.latitude,
      lng: _currentPosition?.longitude,
    );

    // Text payload - iOS için ana kanal (localName içinde)
    final textName = _MeshPayload.encodeText(
      msgType: _currentMsgType,
      bloodType: profile.bloodType,
      name: profile.bleDisplayName,
      lat: _currentPosition?.latitude,
      lng: _currentPosition?.longitude,
    );

    try {
      try {
        await _peripheral.stop();
      } catch (_) {}

      // iOS/Android cihaz BLE peripheral destekliyor mu kontrol et
      try {
        final supported = await _peripheral.isSupported;
        if (!supported) {
          statusNotifier.value = 'Bu cihaz BLE yayın desteklemiyor';
          debugPrint('BLE peripheral desteklenmiyor');
          return;
        }
      } catch (e) {
        debugPrint('isSupported kontrol hatası: $e');
      }

      final settings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeLowLatency,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: false,
      );

      // Oppo/Realme/Vivo cihazlarda startAdvertisingSet legacy olmayan modda
      // bug'lı (PlatformException 18 UNDOCUMENTED). legacyMode=true ile
      // BLE 4.x uyumlu modu zorlarız - bu Oppo'da çalışır.
      final setParams = AdvertiseSetParameters(
        connectable: false,
        legacyMode: true,
      );

      // FALLBACK STRATEJİSİ - Oppo/Vivo/Realme gibi cihazlarda 31 byte
      // sınırı var, hepsi sığmıyor. Sırayla denenir, biri tutarsa devam.
      final attempts = <_AdvertiseAttempt>[];

      if (Platform.isAndroid) {
        // 1. Tam payload (modern cihazlar - extended advertising destekleyenler)
        attempts.add(_AdvertiseAttempt(
          'tam',
          AdvertiseData(
            includeDeviceName: false,
            serviceUuid: meshServiceUuid,
            localName: textName,
            manufacturerId: _manufacturerId,
            manufacturerData: binaryPayload,
          ),
        ));
        // 2. Service UUID + manufacturer (localName olmadan, ~50 byte)
        attempts.add(_AdvertiseAttempt(
          'orta',
          AdvertiseData(
            includeDeviceName: false,
            serviceUuid: meshServiceUuid,
            manufacturerId: _manufacturerId,
            manufacturerData: binaryPayload,
          ),
        ));
        // 3. Sadece manufacturer data (en kompakt, ~30 byte) - Oppo dahil
        attempts.add(_AdvertiseAttempt(
          'minimum',
          AdvertiseData(
            includeDeviceName: false,
            manufacturerId: _manufacturerId,
            manufacturerData: binaryPayload,
          ),
        ));
        // 4. Service UUID + minimum localName (manufacturerData yok)
        attempts.add(_AdvertiseAttempt(
          'sadece-uuid',
          AdvertiseData(
            includeDeviceName: false,
            serviceUuid: meshServiceUuid,
          ),
        ));
      } else {
        // iOS: Tek seçenek
        attempts.add(_AdvertiseAttempt(
          'ios',
          AdvertiseData(
            serviceUuid: meshServiceUuid,
            localName: textName,
          ),
        ));
      }

      Object? lastError;
      for (final attempt in attempts) {
        try {
          // Her denemede önceki yayını durdur
          try { await _peripheral.stop(); } catch (_) {}

          // ÖNCE legacy mode advertiseSet ile dene (Oppo dahil çoğu cihaz)
          try {
            await _peripheral.start(
              advertiseData: attempt.data,
              advertiseSetParameters: setParams,
            );
          } catch (e1) {
            // Legacy mode da olmadıysa eski settings ile dene
            debugPrint('Legacy mode ${attempt.label} başarısız: $e1, '
                'eski settings ile deneniyor');
            await _peripheral.start(
              advertiseData: attempt.data,
              advertiseSettings: settings,
            );
          }

          _isBroadcasting = true;
          isBroadcastingNotifier.value = true;
          if (attempt.label == 'tam' || attempt.label == 'ios') {
            statusNotifier.value = 'Yayında: ${_currentMsgType.label}';
          } else {
            statusNotifier.value =
                'Yayında (${attempt.label} mod): ${_currentMsgType.label}';
          }
          debugPrint('Yayın başarılı: ${attempt.label} payload');
          return;
        } catch (e) {
          lastError = e;
          debugPrint('Yayın denemesi "${attempt.label}" başarısız: $e');
          continue;
        }
      }

      // Hepsi başarısız - en son hatayı kullanıcıya göster, scan devam etsin
      _isBroadcasting = false;
      isBroadcastingNotifier.value = false;

      final errMsg = (lastError ?? 'bilinmiyor').toString();
      debugPrint('====== TÜM YAYIN DENEMELERI BAŞARISIZ ======');
      debugPrint('Son hata: $errMsg');
      debugPrint('============================================');

      if (errMsg.contains('not supported') ||
          errMsg.contains('UNSUPPORTED')) {
        statusNotifier.value =
            'Cihaz yayın yapamıyor — sadece dinleme modunda';
      } else if (errMsg.contains('PERMISSION') ||
          errMsg.contains('permission')) {
        statusNotifier.value = 'BLE izni eksik - ayarlardan ver';
      } else if (errMsg.contains('TOO_LARGE') ||
          errMsg.contains('too large') ||
          errMsg.contains('DATA_TOO_LARGE')) {
        statusNotifier.value = 'Veri çok büyük - cihaz desteklemiyor';
      } else if (errMsg.toLowerCase().contains('bluetooth') &&
          (errMsg.contains('off') || errMsg.contains('disabled'))) {
        statusNotifier.value = 'Bluetooth kapalı';
      } else {
        final shortErr =
            errMsg.length > 60 ? '${errMsg.substring(0, 60)}...' : errMsg;
        statusNotifier.value = 'Yayın yapılamadı: $shortErr';
      }
    } catch (e, stack) {
      debugPrint('Beklenmedik hata: $e\n$stack');
      statusNotifier.value = 'Beklenmedik hata: $e';
    }
  }

  Future<bool> _checkPermissions() async {
    if (!Platform.isAndroid) return true;

    // SCAN için zorunlu izinler
    final scan = await Permission.bluetoothScan.request();
    if (!scan.isGranted) {
      statusNotifier.value = 'Bluetooth Tarama izni gerekli';
      return false;
    }
    final connect = await Permission.bluetoothConnect.request();
    if (!connect.isGranted) {
      statusNotifier.value = 'Bluetooth Bağlantı izni gerekli';
      return false;
    }
    final loc = await Permission.locationWhenInUse.request();
    if (!loc.isGranted) {
      statusNotifier.value = 'Konum izni gerekli (BLE tarama için)';
      return false;
    }

    // Advertise izni opsiyonel - olmasa bile scan çalışmalı.
    // Sessizce dene, reddedilirse ileride yayın denenirken hata gösterilir.
    try {
      await Permission.bluetoothAdvertise.request();
    } catch (_) {}

    return true;
  }

  Future<void> _startLocationTracking() async {
    try {
      final hasService = await Geolocator.isLocationServiceEnabled();
      if (!hasService) return;

      // Tek seferlik hızlı başlangıç
      try {
        _currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {}

      // Sürekli güncelleme
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        _currentPosition = pos;
        _refreshAllNodeBearings();
      });

      // Pusula
      _compassSub = FlutterCompass.events?.listen((event) {
        _currentHeading = event.heading;
      });
    } catch (e) {
      debugPrint('Konum tracking hatası: $e');
    }
  }

  void _processScanResults(List<ScanResult> results) {
    bool changed = false;
    final now = DateTime.now();

    for (final r in results) {
      _DecodedPayload? decoded;
      String detectionSource = ''; // debug için

      // 1. ÖNCELİK: Manufacturer data (Android binary protokol)
      final mfr = r.advertisementData.manufacturerData;
      final raw = mfr[_manufacturerId];
      if (raw != null) {
        decoded = _MeshPayload.decode(Uint8List.fromList(raw));
        if (decoded != null) detectionSource = 'manufacturer';
      }

      // 2. YEDEK: localName text protokol (iOS / Android background)
      if (decoded == null) {
        final localName = r.advertisementData.advName;
        if (localName.startsWith(_MeshPayload.textPrefix)) {
          decoded = _MeshPayload.decodeText(localName);
          if (decoded != null) detectionSource = 'localName';
        }
      }

      // 3. YEDEK: Service UUID varsa "anonim" olarak göster (Oppo edge-case)
      // Oppo'da bazen sadece service UUID gelir, manufacturer ve localName boş.
      if (decoded == null) {
        final hasOurService = r.advertisementData.serviceUuids.any(
          (uuid) => uuid.str.toLowerCase() == meshServiceUuid.toLowerCase(),
        );
        if (!hasOurService) continue; // Bizim app değil
        decoded = _DecodedPayload(
          msgType: MeshMsgType.presence,
          bloodType: '?',
          name: 'Kullanıcı',
        );
        detectionSource = 'serviceUuid-only';
      }

      final macId = r.device.remoteId.str;
      final name = decoded.name.isNotEmpty ? decoded.name : 'Anonim';

      // ⭐ KIMLIK ÇÖZÜMÜ - Bug Fix #1
      // BLE MAC adresi privacy için sürekli rotate olduğu için (özellikle
      // Android 9+), aynı kişi farklı MAC ile gelir → 4 kart problemi.
      // Çözüm: Anlamlı veri varsa name+blood key kullan.
      // Anonim ise (sadece serviceUuid) MAC'i fallback olarak kullan.
      final String nodeKey;
      if (detectionSource == 'serviceUuid-only') {
        // Anonim node, MAC ile takip et (en azından sahte tekrar olmaz)
        nodeKey = 'anon_$macId';
      } else {
        // Tanınan kişi: isim+kan grubu unique key (case-insensitive)
        nodeKey = 'user_${name.toLowerCase().trim()}_${decoded.bloodType}';
      }

      // Mesafe (RSSI bazlı tahmin)
      int txPower = -59;
      if (r.advertisementData.txPowerLevel != null) {
        txPower = r.advertisementData.txPowerLevel!;
      }
      final rssiDist = math.pow(10, (txPower - r.rssi) / 27.55).toDouble();

      // GPS bazlı mesafe ve yön
      double? gpsDist;
      double? bearing;
      if (decoded.lat != null &&
          decoded.lng != null &&
          _currentPosition != null) {
        gpsDist = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          decoded.lat!,
          decoded.lng!,
        );
        bearing = Geolocator.bearingBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          decoded.lat!,
          decoded.lng!,
        );
      }

      // Mevcut kayıt varsa, sadece daha güçlü sinyal geldiyse RSSI güncelle
      // (zayıf duvar arkası sinyali güçlüyü ezmesin)
      final existing = _foundNodes[nodeKey];
      final useNewRssi = existing == null || r.rssi >= existing.rssi - 5;

      _foundNodes[nodeKey] = MeshNode(
        id: macId, // Son görülen MAC, debug ID için
        name: name,
        bloodType: decoded.bloodType,
        rssi: useNewRssi ? r.rssi : existing!.rssi,
        distanceMeters: useNewRssi ? rssiDist : existing!.distanceMeters,
        gpsDistanceMeters: gpsDist ?? existing?.gpsDistanceMeters,
        bearingDegrees: bearing ?? existing?.bearingDegrees,
        latitude: decoded.lat ?? existing?.latitude,
        longitude: decoded.lng ?? existing?.longitude,
        messageType: decoded.msgType,
        lastSeen: now,
      );
      changed = true;
    }

    if (changed) _emit();
  }

  void _refreshAllNodeBearings() {
    if (_currentPosition == null) return;
    final updated = <String, MeshNode>{};
    for (final entry in _foundNodes.entries) {
      final n = entry.value;
      if (n.latitude != null && n.longitude != null) {
        final dist = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          n.latitude!,
          n.longitude!,
        );
        final bearing = Geolocator.bearingBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          n.latitude!,
          n.longitude!,
        );
        updated[entry.key] = MeshNode(
          id: n.id,
          name: n.name,
          bloodType: n.bloodType,
          rssi: n.rssi,
          distanceMeters: n.distanceMeters,
          gpsDistanceMeters: dist,
          bearingDegrees: bearing,
          latitude: n.latitude,
          longitude: n.longitude,
          messageType: n.messageType,
          lastSeen: n.lastSeen,
        );
      } else {
        updated[entry.key] = n;
      }
    }
    _foundNodes
      ..clear()
      ..addAll(updated);
    _emit();
  }

  void _cleanupStaleNodes() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 45));
    final before = _foundNodes.length;
    _foundNodes.removeWhere((_, n) => n.lastSeen.isBefore(cutoff));
    if (_foundNodes.length != before) _emit();
  }

  void _emit() {
    final list = _foundNodes.values.toList();
    // SOS önce, sonra mesafeye göre
    list.sort((a, b) {
      if (a.isAlerting && !b.isAlerting) return -1;
      if (!a.isAlerting && b.isAlerting) return 1;
      final da = a.gpsDistanceMeters ?? a.distanceMeters;
      final db = b.gpsDistanceMeters ?? b.distanceMeters;
      return da.compareTo(db);
    });
    _nodesController.add(list);
  }

  // Pusula heading'i (0=Kuzey). UI raptiyesi için.
  double? get currentHeading => _currentHeading;
  Position? get currentPosition => _currentPosition;
  bool get isBroadcasting => _isBroadcasting;
  MeshMsgType get currentMessageType => _currentMsgType;

  // -------- SİMÜLASYON --------
  Timer? _simTimer;
  void _startSimulation() {
    _isScanning = true;
    _simTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!_isScanning) {
        t.cancel();
        return;
      }
      final now = DateTime.now();
      _foundNodes['sim_1'] = MeshNode(
        id: 'sim_1',
        name: 'Mehmet K.',
        bloodType: 'A+',
        rssi: -55,
        distanceMeters: 5.2,
        gpsDistanceMeters: 12.3,
        bearingDegrees: 45,
        latitude: 41.0082,
        longitude: 28.9784,
        messageType: MeshMsgType.presence,
        lastSeen: now,
      );
      _foundNodes['sim_2'] = MeshNode(
        id: 'sim_2',
        name: 'Ayşe D.',
        bloodType: '0+',
        rssi: -75,
        distanceMeters: 18.0,
        gpsDistanceMeters: 24.7,
        bearingDegrees: 200,
        latitude: 41.0072,
        longitude: 28.9774,
        messageType: MeshMsgType.sos,
        lastSeen: now,
      );
      _emit();
    });
  }
}

class _AdvertiseAttempt {
  final String label;
  final AdvertiseData data;
  _AdvertiseAttempt(this.label, this.data);
}
