import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/docs/widgets/docs_overview_page.dart';
import 'package:asr_application/ui/docs/widgets/localized_markdown_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/utils/test_helpers.dart';

void main() {
  Future<void> pumpDocsOverview(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(fontFamily: ThemeFontFamily().arial),
        home: const DocsOverviewPage(),
      ),
    );
  }

  group('Docs overview page', () {
    testWidgets('shows localized document links', (tester) async {
      await pumpDocsOverview(tester);

      expect(find.text(AppLocalizationsEn().docs__title), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().docs__addingModelsTitle),
        findsOneWidget,
      );
      expect(find.text(AppLocalizationsEn().docs__aboutTitle), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().docs__disclaimerTitle),
        findsOneWidget,
      );
      expect(find.text(AppLocalizationsEn().settings__back), findsOneWidget);
    });

    testWidgets('opens the adding models page', (tester) async {
      await pumpDocsOverview(tester);

      await tester.tap(find.text(AppLocalizationsEn().docs__addingModelsTitle));
      await tester.pumpAndSettle();

      expect(find.byType(LocalizedMarkdownPage), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().docs__addingModelsTitle),
        findsNWidgets(2),
      );
      expect(markdownData(tester), contains('There are two ways to add'));
    });

    testWidgets('opens the about page', (tester) async {
      await pumpDocsOverview(tester);

      await tester.tap(find.text(AppLocalizationsEn().docs__aboutTitle));
      await tester.pumpAndSettle();

      expect(find.byType(LocalizedMarkdownPage), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().docs__aboutTitle),
        findsNWidgets(2),
      );
      expect(markdownData(tester), contains('originally developed'));
    });

    testWidgets('opens the disclaimer page', (tester) async {
      await pumpDocsOverview(tester);

      await tester.tap(find.text(AppLocalizationsEn().docs__disclaimerTitle));
      await tester.pumpAndSettle();

      expect(find.byType(LocalizedMarkdownPage), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().docs__disclaimerTitle),
        findsNWidgets(2),
      );
      expect(markdownData(tester), contains('Generated transcriptions'));
      expect(markdownData(tester), isNot(contains('originally developed')));
    });
  });
}
