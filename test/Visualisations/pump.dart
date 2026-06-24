import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

Future<SettingsRepository> pump(
  WidgetTester tester,
  Widget body, {
  Future<void> Function(String key, String value)? settingsSaveFunc,
  Map<String, String>? settingsPreferences,
}) async {
  final settings = SettingsRepository(
    save: settingsSaveFunc ?? (String k, String v) async => Mock(),
    remove: (String k) async => Mock(),
    preferences: settingsPreferences ?? {},
  );
  settings.setFontsize(AppFontSizeOption.xl);

  await tester.pumpWidget(
    AppSettingsScope(
      settings: settings,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(fontFamily: ThemeFontFamily().arial),
        home: body,
      ),
    ),
  );

  return settings;
}
