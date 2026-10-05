import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı profili: isim, soyisim, kan grubu.
/// SharedPreferences ile saklanır, BLE Mesh üzerinde yayınlanır.
class UserProfile {
  final String firstName;
  final String lastName;
  final String bloodType; // "A+", "0-" gibi

  UserProfile({
    required this.firstName,
    required this.lastName,
    required this.bloodType,
  });

  String get fullName => '$firstName $lastName'.trim();

  /// BLE advertise için kısa görünen ad: "Ahmet Y." gibi (maks ~14 karakter).
  String get bleDisplayName {
    final fn = firstName.trim();
    final ln = lastName.trim();
    if (fn.isEmpty && ln.isEmpty) return 'Anonim';
    if (ln.isEmpty) return fn;
    final lastInitial = ln.substring(0, 1).toUpperCase();
    final base = '$fn $lastInitial.';
    if (base.length > 14) return base.substring(0, 14);
    return base;
  }

  bool get isComplete =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      bloodType.trim().isNotEmpty;
}

class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  static const _kFirstName = 'profile_first_name';
  static const _kLastName = 'profile_last_name';
  static const _kBloodType = 'profile_blood_type';

  static const List<String> bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-', 'Bilmiyorum'
  ];

  UserProfile? _cached;
  UserProfile? get current => _cached;

  Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final p = UserProfile(
      firstName: prefs.getString(_kFirstName) ?? '',
      lastName: prefs.getString(_kLastName) ?? '',
      bloodType: prefs.getString(_kBloodType) ?? '',
    );
    _cached = p;
    return p;
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFirstName, profile.firstName.trim());
    await prefs.setString(_kLastName, profile.lastName.trim());
    await prefs.setString(_kBloodType, profile.bloodType.trim());
    _cached = profile;
  }

  Future<bool> hasProfile() async {
    final p = await load();
    return p.isComplete;
  }
}
