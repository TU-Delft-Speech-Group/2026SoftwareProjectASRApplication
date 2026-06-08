import 'package:flutter/material.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({Locale? locale}) : _locale = locale;

  Locale? _locale;

  Locale? get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) {
      return;
    }

    _locale = locale;
    notifyListeners();
  }
}
