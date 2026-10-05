# PulseTR — Deprem Takip ve Afet Uygulaması

Türkiye'deki depremleri anlık takip eden, yakınında deprem olduğunda bildirim gönderen ve afet anında internet olmadan da çalışan araçlar sunan bir Flutter uygulaması.

## Özellikler

### Deprem takibi
- **Yedekli veri kaynakları:** Kandilli Rasathanesi'nin resmi listesi (HTML'den ayrıştırılarak), AFAD API'si ve yedek olarak üçüncü parti bir Kandilli API'si. Bir kaynak cevap vermezse sıradakine geçilir, verinin hangi kaynaktan geldiği ekranda gösterilir.
- 10 saniyede bir otomatik güncelleme
- Harita üzerinde deprem konumları ve detay sayfası

### Bildirimler
- Uygulama kapalıyken de çalışan arka plan servisi
- Kullanıcının seçtiği minimum büyüklük ve mesafe filtresine göre bildirim
- Konuma yakın depremler için uyarı

### Afet modu (internet gerektirmez)
- **Bluetooth ile yakındaki kullanıcılar:** Bluetooth Low Energy yayın paketleri üzerinden çevredeki uygulama kullanıcılarını bulur; "buradayım", "SOS", "güvendeyim" ve "yardım lazım" durumlarını konumla birlikte paylaşır. Yakındakilerin yönü ve mesafesi gösterilir, haritada işaretlenir.
- **Yardım çağrısı:** konum bilgisini SMS (112) veya WhatsApp ile gönderme
- Düdük ve el feneri
- Hayatta kalma kiti kontrol listesi
- AFAD kaynaklı acil durum rehberleri ve toplanma alanı verileri

## Teknik Detaylar

- **Framework:** Flutter (Dart)
- **Mimari:** `models` / `services` / `views` / `utils` katmanları; veri akışı `ValueNotifier` ile
- **Önemli paketler:**

| Alan | Paket |
| --- | --- |
| Ağ | `http` |
| Harita ve konum | `flutter_map`, `latlong2`, `geolocator` |
| Arka plan ve bildirim | `flutter_background_service`, `flutter_local_notifications` |
| Bluetooth | `flutter_blue_plus`, `flutter_ble_peripheral` |
| Sensörler | `flutter_compass`, `sensors_plus` |
| Diğer | `shared_preferences`, `audioplayers`, `torch_light`, `url_launcher` |

## Kurulum

```bash
flutter pub get
flutter run
```

Bluetooth özellikleri ve arka plan bildirimleri için gerçek bir Android veya iOS cihaz gerekir; emülatörlerde Bluetooth desteklenmez.

## Not

Deprem verileri Kandilli Rasathanesi ve AFAD'dan alınır. Bu uygulama resmi bir erken uyarı sistemi değildir, bilgilendirme amaçlıdır.
