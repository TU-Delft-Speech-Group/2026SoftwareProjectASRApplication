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
    });

    testWidgets('Dutch localization', (tester) async {
      BuildContext context = await createContext(tester, locale: Locale("nl"));
      expect(context.l10n.helloWorld, "Hallo Wereld!");
    });
  });
}
