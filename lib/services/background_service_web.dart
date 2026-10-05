class BackgroundService {
  Future<void> initialize() async {
    print("BackgroundService: Web platformunda devre dışı.");
  }

  void registerPeriodicTask() {
    print("BackgroundService: Web platformunda periyodik görev desteklenmiyor.");
  }
}

void callbackDispatcher() {}
