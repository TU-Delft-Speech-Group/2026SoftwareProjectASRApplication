import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<BuildContext> createContext(
    WidgetTester tester, {
    required Locale locale,
  }) async {
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );

    return context;
  }

  group('Localization tests', () {
    testWidgets('Fallback localization', (tester) async {
      BuildContext context = await createContext(tester, locale: Locale("fr"));
      BuildContext fallback = await createContext(tester, locale: Locale("en"));
      expect(context.l10n.helloWorld, fallback.l10n.helloWorld);
    });

    testWidgets('English localization', (tester) async {
      BuildContext context = await createContext(tester, locale: Locale("en"));
      expect(context.l10n.helloWorld, "Hello World!");
      expect(context.l10n.settings__title, "Settings");
      expect(context.l10n.settings__save, "Save");
      expect(context.l10n.settings__addModel, "Add model");
      expect(context.l10n.addModel__name, "Name");
      expect(context.l10n.addModel__modelLink, "Model link");
      expect(context.l10n.addModel__downloadModel, "Download");
      expect(context.l10n.addModel__sourceSeparator, "OR");
      expect(context.l10n.addModel__loadModel, "Load model");
      expect(context.l10n.settings__fontSize, "Font size");
      expect(context.l10n.settings__fontSizeMedium, "Medium");
      expect(context.l10n.settings__fontSizeLarge, "Larger");
      expect(context.l10n.settings__fontSizeXl, "XL");
      expect(context.l10n.settings__language, "Language");
      expect(context.l10n.settings__languageEnglish, "English");
      expect(context.l10n.settings__languageDutch, "Dutch");
      expect(context.l10n.settings__languageModel, "Language model");
      expect(context.l10n.settings__back, "Back");
    });

    testWidgets('Dutch localization', (tester) async {
      BuildContext context = await createContext(tester, locale: Locale("nl"));
      expect(context.l10n.helloWorld, "Hallo Wereld!");
      expect(context.l10n.settings__title, "Instellingen");
      expect(context.l10n.settings__save, "Opslaan");
      expect(context.l10n.settings__addModel, "Model toevoegen");
      expect(context.l10n.addModel__name, "Naam");
      expect(context.l10n.addModel__modelLink, "Model link");
      expect(context.l10n.addModel__downloadModel, "Downloaden");
      expect(context.l10n.addModel__sourceSeparator, "OF");
      expect(context.l10n.addModel__loadModel, "Model laden");
      expect(context.l10n.settings__fontSize, "Lettergrootte");
      expect(context.l10n.settings__fontSizeMedium, "Medium");
      expect(context.l10n.settings__fontSizeLarge, "Groter");
      expect(context.l10n.settings__fontSizeXl, "XL");
      expect(context.l10n.settings__language, "Taal");
      expect(context.l10n.settings__languageEnglish, "Engels");
      expect(context.l10n.settings__languageDutch, "Nederlands");
      expect(context.l10n.settings__languageModel, "Taal model");
      expect(context.l10n.settings__back, "Terug");
    });
  });
}
