class SubscriptionService {
  // Singleton pattern
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  bool _isPremium = false;

  bool get isPremium => _isPremium;

  void setPremium(bool value) {
    _isPremium = value;
  }
}
