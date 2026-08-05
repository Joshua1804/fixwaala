import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local key-value storage.
///
/// Every method here used to be an empty body or `return null`, so anything
/// "saved" was discarded — theme choice, notification toggle, and language all
/// reset to defaults on every launch.
///
/// Deliberately **not** for anything sensitive: `SharedPreferences` is plain
/// text on disk. Credentials and tokens stay with Firebase Auth.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (error) {
      // A device that cannot provide preferences should still run — the app
      // simply falls back to defaults each launch.
      debugPrint('[StorageService] Unavailable, using defaults: $error');
    }
  }

  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  String? getString(String key) => _prefs?.getString(key);

  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  bool? getBool(String key) => _prefs?.getBool(key);

  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  Future<void> clear() async {
    await _prefs?.clear();
  }
}
