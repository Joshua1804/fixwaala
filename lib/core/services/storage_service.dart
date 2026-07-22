/// Local key-value + session cache (SharedPreferences / secure storage).
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  Future<void> initialize() async {
    // TODO: obtain SharedPreferences instance.
  }

  Future<void> setString(String key, String value) async {}
  Future<String?> getString(String key) async => null;

  Future<void> setRole(String role) => setString('role', role);
  Future<String?> getRole() => getString('role');

  Future<void> clear() async {}
}
