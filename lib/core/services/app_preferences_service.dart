import 'dart:async';
import 'package:flutter/material.dart';

class AppPreferencesService {
  AppPreferencesService._();
  static final AppPreferencesService instance = AppPreferencesService._();

  final _themeModeController = StreamController<ThemeMode>.broadcast();
  final _notificationsEnabledController = StreamController<bool>.broadcast();
  final _languageController = StreamController<String>.broadcast();

  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  String _language = 'en';

  Future<void> initialize() async {
    // TODO: Load preferences from storage when StorageService is fully implemented
    _themeMode = ThemeMode.system;
    _notificationsEnabled = true;
    _language = 'en';
  }

  // Theme
  Stream<ThemeMode> get themeModeStream => _themeModeController.stream;
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _themeModeController.add(mode);
    // TODO: Persist to StorageService
  }

  // Notifications
  Stream<bool> get notificationsEnabledStream => _notificationsEnabledController.stream;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    _notificationsEnabledController.add(enabled);
    // TODO: Persist to StorageService
  }

  // Language
  Stream<String> get languageStream => _languageController.stream;
  String get language => _language;

  Future<void> setLanguage(String lang) async {
    _language = lang;
    _languageController.add(lang);
    // TODO: Persist to StorageService
  }

  void dispose() {
    _themeModeController.close();
    _notificationsEnabledController.close();
    _languageController.close();
  }
}
