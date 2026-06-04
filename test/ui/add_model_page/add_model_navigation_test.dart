import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/ui/add_model/widgets/add_model_page.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> generateWidget(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(fontFamily: ThemeFontFamily().arial),
        home: HomePage(viewModel: HomeViewModel()),
      ),
    );
  }

  Future<void> openAddModelPage(WidgetTester tester) async {
    await generateWidget(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().settings__addModel));
    await tester.pumpAndSettle();
  }

  group('Add model navigation', () {
    testWidgets('add model button opens add model page', (tester) async {
      await openAddModelPage(tester);

      expect(find.byType(AddModelPage), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().settings__addModel),
        findsOneWidget,
      );
      expect(find.text(AppLocalizationsEn().settings__save), findsOneWidget);
      expect(find.text(AppLocalizationsEn().settings__back), findsOneWidget);
      expect(find.text(AppLocalizationsEn().settings__title), findsNothing);
    });

    testWidgets('save button stays on add model page', (tester) async {
      await openAddModelPage(tester);

      await tester.tap(find.text(AppLocalizationsEn().settings__save));
      await tester.pumpAndSettle();

      expect(find.byType(AddModelPage), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().settings__addModel),
        findsOneWidget,
      );
      expect(find.text(AppLocalizationsEn().settings__title), findsNothing);
    });

    testWidgets('back button returns from add model page to settings page', (
      tester,
    ) async {
      await openAddModelPage(tester);

      await tester.tap(find.text(AppLocalizationsEn().settings__back));
      await tester.pumpAndSettle();

      expect(find.byType(AddModelPage), findsNothing);
      expect(find.text(AppLocalizationsEn().settings__title), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().settings__addModel),
        findsOneWidget,
      );
    });
  });
}
