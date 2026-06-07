import 'package:flutter/material.dart';

enum AppFontSizeOption { medium, large, xl }

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    Locale? locale, 
    AppFontSizeOption fontSize = AppFontSizeOption.medium
  }) : 
    _locale = locale,
    _fontSize = fontSize;

  Locale? _locale;
  AppFontSizeOption _fontSize;

  Locale? get locale => _locale;
  AppFontSizeOption get fontSize => _fontSize;

  void setLocale(Locale locale) {
    if (_locale == locale) {
      return;
    }

    _locale = locale;
    notifyListeners();
  }

  void setFontSize(AppFontSizeOption fontSize) {
    if (_fontSize == fontSize) {
      return;
    }

    _fontSize = fontSize;
    notifyListeners();
  }
}
