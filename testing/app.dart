import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:mockito/mockito.dart';

Future<void> testApp(
  WidgetTester tester,
  Widget body, {
  Future<void> Function(String key, String value)? settingsSaveFunc,
  Map<String, String>? settingsPreferences,
}) async {
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(const Size(1200, 800));

  await tester.pumpWidget(
    AppSettingsScope(
      settings: SettingsRepository(
        save: settingsSaveFunc ?? (String k, String v) async => Mock(),
        remove: (String k) async => Mock(),
        preferences: settingsPreferences ?? {},
      ),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(fontFamily: ThemeFontFamily().arial),
        home: body,
      ),
    ),
  );
}
