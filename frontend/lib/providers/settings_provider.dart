import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/update_service.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');
  UpdateInfo? _updateInfo;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  UpdateInfo? get updateInfo => _updateInfo;
  bool get hasUpdate => _updateInfo != null;

  final UpdateService _updateService = UpdateService();

  SettingsProvider() {
    _loadSettings();
    checkForUpdate(); // Check on startup
  }

  Future<void> checkForUpdate() async {
    _updateInfo = await _updateService.checkUpdate();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode');
    final localeString = prefs.getString('locale');

    if (themeString != null) {
      if (themeString == 'light') _themeMode = ThemeMode.light;
      if (themeString == 'dark') _themeMode = ThemeMode.dark;
      if (themeString == 'system') _themeMode = ThemeMode.system;
    }

    if (localeString != null) {
      _locale = Locale(localeString);
    }
    
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await prefs.setString('theme_mode', modeStr);
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
  }
}
