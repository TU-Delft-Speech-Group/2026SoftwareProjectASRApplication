import 'package:flutter/material.dart';

enum AppFontSizeOption { medium, large, xl }

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    Locale? locale,
    AppFontSizeOption fontSize = AppFontSizeOption.medium,
    bool splitScreen = false,
  }) : _locale = locale,
       _fontSize = fontSize,
       _splitScreen = splitScreen;

  Locale? _locale;
  AppFontSizeOption _fontSize;
  bool _splitScreen;

  Locale? get locale => _locale;
  AppFontSizeOption get fontSize => _fontSize;
  bool get splitScreen => _splitScreen;

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

  void setSplitScreen(bool splitScreen) {
    if (_splitScreen == splitScreen) {
      return;
    }

    _splitScreen = splitScreen;
    notifyListeners();
  }
}
