import 'package:flutter/material.dart';

enum AppFontSizeOption { medium, large, xl }

enum SettingsKey { fontsize, locale, model, splitscreen }

class SettingsRepository extends ChangeNotifier {
  static const settingsPrefix = 'settings_';

  final Future<void> Function(String key, String value) _save;
  final Map<String, String?> _preferences;

  SettingsRepository({
    required Future<void> Function(String key, String value) save,
    required Map<String, String?> preferences,
  }) : _save = save,
       _preferences = preferences;

  static AppFontSizeOption getDefaultFontsize() => AppFontSizeOption.medium;
  AppFontSizeOption getFontsize() =>
      _preferences.containsKey(_keyToString(.fontsize))
      ? _withFallback(
          () => _strToFontsize(_preferences[_keyToString(.fontsize)]!),
          getDefaultFontsize(),
        )
      : getDefaultFontsize();
  Future<void> setFontsize(AppFontSizeOption fontsize) async {
    final key = _keyToString(.fontsize);

    _preferences[key] = fontsize.name;
    await _save(key, fontsize.name);
    notifyListeners();
  }

  static Locale getDefaultLocale() => Locale.fromSubtags(languageCode: 'en');
  Locale getLocale() => _preferences.containsKey(_keyToString(.locale))
      ? _withFallback(
          () => Locale.fromSubtags(
            languageCode: _preferences[_keyToString(.locale)]!,
          ),
          getDefaultLocale(),
        )
      : getDefaultLocale();
  Future<void> setLocale(Locale locale) async {
    final key = _keyToString(.locale);

    _preferences[key] = locale.languageCode;
    await _save(key, locale.languageCode);
    notifyListeners();
  }

  String? getModelName() => _preferences[_keyToString(.model)];
  Future<void> setModelName(String modelName) async {
    final key = _keyToString(.model);

    _preferences[key] = modelName;
    await _save(key, modelName);
    notifyListeners();
  }

  bool getDefaultSplitscreen() => false;
  bool getSplitscreen() => _preferences.containsKey(_keyToString(.splitscreen))
      ? bool.parse(_preferences[_keyToString(.splitscreen)]!)
      : getDefaultSplitscreen();
  Future<void> setSplitscreen(bool splitscreen) async {
    final key = _keyToString(.splitscreen);

    _preferences[key] = splitscreen.toString();
    await _save(key, splitscreen.toString());
    notifyListeners();
  }

  String _keyToString(SettingsKey key) => '$settingsPrefix${key.name}';

  T _withFallback<T>(T Function() func, T fallback) => func() ?? fallback;

  AppFontSizeOption _strToFontsize(String s) =>
      AppFontSizeOption.values.firstWhere((val) => val.name == s);
}
