import 'package:flutter/material.dart';

/// A simple app-wide theme manager.
/// Use the global instance `themeManager` to read/update theme settings.
class ThemeManager extends ChangeNotifier {
  ThemeManager({ThemeMode? mode, Color? seedColor})
      : _mode = mode ?? ThemeMode.light,
        _seedColor = seedColor ?? Colors.red;

  ThemeMode _mode;
  Color _seedColor;

  ThemeMode get mode => _mode;
  Color get seedColor => _seedColor;

  void setThemeMode(ThemeMode newMode) {
    if (newMode == _mode) return;
    _mode = newMode;
    notifyListeners();
  }

  void toggleDark(bool darkOn) {
    setThemeMode(darkOn ? ThemeMode.dark : ThemeMode.light);
  }

  void setSeedColor(Color color) {
    if (color == _seedColor) return;
    _seedColor = color;
    notifyListeners();
  }
}

final themeManager = ThemeManager();
