import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../utils/StockageKeys.dart';

class ThemeController with ChangeNotifier {
  final GetStorage _storage = GetStorage();
  ThemeMode _themeMode = ThemeMode.light;

  ThemeController() {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void _loadThemeMode() {
    final savedTheme = _storage.read<String>(StockageKeys.themeModeKey);
    if (savedTheme != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == savedTheme,
        orElse: () => ThemeMode.light,
      );
    } else {
      // Par défaut, suivre le thème système
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _storage.write(StockageKeys.themeModeKey, mode.toString());
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      // Si c'est system, basculer vers dark
      setThemeMode(ThemeMode.dark);
    }
  }
}




