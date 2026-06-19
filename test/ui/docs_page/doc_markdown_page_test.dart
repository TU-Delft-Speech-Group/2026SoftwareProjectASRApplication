import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/l10n/generated/app_localizations_nl.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/docs/widgets/localized_markdown_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  Future<void> pumpMarkdownPage(
    WidgetTester tester, {
    required LocalizedMarkdownDocument document,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final supportedLocales = AppLocalizations.supportedLocales.contains(locale)
        ? AppLocalizations.supportedLocales
        : [...AppLocalizations.supportedLocales, locale];

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: supportedLocales,
        theme: ThemeData(fontFamily: ThemeFontFamily().arial),
        home: LocalizedMarkdownPage(document: document),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Localized markdown page', () {
    testWidgets('loads English markdown for the English locale', (
      tester,
    ) async {
      await pumpMarkdownPage(
        tester,
        document: LocalizedMarkdownDocument(
          name: 'about',
          title: AppLocalizationsEn().docs__aboutTitle,
        ),
      );

      expect(markdownData(tester), contains('# About DISC'));
      expect(markdownData(tester), contains('originally developed'));
    });

    testWidgets('loads Dutch markdown for the Dutch locale', (tester) async {
      await pumpMarkdownPage(
        tester,
        locale: const Locale('nl'),
        document: LocalizedMarkdownDocument(
          name: 'about',
          title: AppLocalizationsNl().docs__aboutTitle,
        ),
      );

      expect(markdownData(tester), contains('# Over DISC'));
      expect(markdownData(tester), contains('oorspronkelijk ontwikkeld'));
    });

    testWidgets('falls back to English when localized markdown is missing', (
      tester,
    ) async {
      await pumpMarkdownPage(
        tester,
        locale: const Locale('nl'),
        document: const LocalizedMarkdownDocument(
          name: 'hello_world',
          title: 'Hello world',
        ),
      );

      expect(markdownData(tester), contains('# Hello World'));
      expect(markdownData(tester), contains('This file is used for testing'));
    });

    testWidgets('shows an error when markdown cannot be loaded', (
      tester,
    ) async {
      await pumpMarkdownPage(
        tester,
        document: const LocalizedMarkdownDocument(
          name: 'missing_document',
          title: 'Missing',
        ),
      );

      expect(find.byType(Markdown), findsNothing);
      expect(
        find.text(AppLocalizationsEn().errors_markdownRender),
        findsOneWidget,
      );
    });
  });
}
