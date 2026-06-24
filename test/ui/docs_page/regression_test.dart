import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/docs/widgets/docs_overview_page.dart';
import 'package:asr_application/ui/docs/widgets/localized_markdown_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:snaptest/snaptest.dart';

void main() {
  late SettingsRepository settingsRepository;

  setUp(() {
    settingsRepository = SettingsRepository(
      save: (String k, String v) async {},
      preferences: {},
      remove: (String k) async => Mock(),
    );
  });

  Future<void> loadScreen(
    WidgetTester tester,
    Widget page, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settingsRepository,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(fontFamily: ThemeFontFamily().arial),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  snapTest('Docs page - overview', (tester) async {
    await loadScreen(tester, const DocsOverviewPage());

    await snap(name: 'docs_overview', matchToGolden: true);
  });

  snapTest('Docs page - markdown article', (tester) async {
    await loadScreen(
      tester,
      LocalizedMarkdownPage(
        document: LocalizedMarkdownDocument(
          name: 'about',
          title: AppLocalizationsEn().docs__aboutTitle,
        ),
      ),
    );

    await snap(name: 'docs_markdown_article', matchToGolden: true);
  });
}
