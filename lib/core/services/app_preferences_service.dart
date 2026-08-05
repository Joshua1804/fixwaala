import 'dart:async';

import 'package:flutter/material.dart';

import 'storage_service.dart';

/// User-facing app preferences, persisted across launches.
///
/// [initialize] previously hardcoded the defaults with a `TODO`, and every
/// setter updated memory only — so choosing a dark theme lasted exactly as
/// long as the process did.
class AppPreferencesService {
  AppPreferencesService._();
  static final AppPreferencesService instance = AppPreferencesService._();

  static const _themeKey = 'pref_theme_mode';
  static const _notificationsKey = 'pref_notifications_enabled';
  static const _languageKey = 'pref_language';

  final _themeModeController = StreamController<ThemeMode>.broadcast();
  final _notificationsEnabledController = StreamController<bool>.broadcast();
  final _languageController = StreamController<String>.broadcast();

  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  String _language = 'en';

  Future<void> initialize() async {
    await StorageService.instance.initialize();

    final storedTheme = StorageService.instance.getString(_themeKey);
    _themeMode =
        ThemeMode.values.where((m) => m.name == storedTheme).firstOrNull ??
        ThemeMode.system;

    _notificationsEnabled =
        StorageService.instance.getBool(_notificationsKey) ?? true;
    _language = StorageService.instance.getString(_languageKey) ?? 'en';
  }

  // Theme
  Stream<ThemeMode> get themeModeStream => _themeModeController.stream;
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _themeModeController.add(mode);
    await StorageService.instance.setString(_themeKey, mode.name);
  }

  // Notifications
  Stream<bool> get notificationsEnabledStream =>
      _notificationsEnabledController.stream;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    _notificationsEnabledController.add(enabled);
    await StorageService.instance.setBool(_notificationsKey, enabled);
  }

  // Language
  Stream<String> get languageStream => _languageController.stream;
  String get language => _language;

  Future<void> setLanguage(String lang) async {
    _language = lang;
    _languageController.add(lang);
    await StorageService.instance.setString(_languageKey, lang);
  }

  void dispose() {
    _themeModeController.close();
    _notificationsEnabledController.close();
    _languageController.close();
  }
}
