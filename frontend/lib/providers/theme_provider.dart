import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Zarządza wyborem motywu jasny/ciemny i zapamiętuje go między
/// uruchomieniami aplikacji. Domyślnie: jasny.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'is_dark_mode';

  bool _isDark = false;
  bool _isReady = false;

  bool get isDark => _isDark;
  bool get isReady => _isReady;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      _isDark = false;
    }
    AppTheme.setDark(_isDark);
    _isReady = true;
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    AppTheme.setDark(value);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // brak zapisu preferencji nie powinien przerywać dzialania aplikacji
    }
  }

  Future<void> toggle() => setDark(!_isDark);
}
