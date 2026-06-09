import 'package:asr_application/app/app_settings_controller.dart';
import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/l10n/generated/app_localizations_nl.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppSettingsController> generateWidget(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final settingsController = AppSettingsController(
      locale: const Locale('en'),
    );

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: settingsController,
        builder: (context, child) {
          return AppSettingsScope(
            controller: settingsController,
            child: MaterialApp(
              locale: settingsController.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(fontFamily: ThemeFontFamily().arial),
              home: HomePage(viewModel: HomeViewModel()),
            ),
          );
        },
      ),
    );

    return settingsController;
  }

  group('Settings navigation', () {
    testWidgets('center of settings button opens settings page', (
      tester,
    ) async {
      await generateWidget(tester);

      final settingsIcon = find.byIcon(Icons.settings);
      final settingsRect = tester.getRect(settingsIcon);

      await tester.tapAt(settingsRect.center);
      await tester.pumpAndSettle();

      expect(find.text(AppLocalizationsEn().settings__title), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().settings__addModel),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__fontSize),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__fontSizeMedium),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__fontSizeLarge),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__fontSizeXl),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__language),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__languageEnglish),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__languageModel),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__modelUser2),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__modelUser1Version),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__modelUser2Version),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__modelStorage),
        findsNWidgets(2),
      );
      expect(find.text(AppLocalizationsEn().settings__save), findsOneWidget);
      expect(find.text(AppLocalizationsEn().settings__back), findsOneWidget);
    });

    testWidgets('save button stays on settings page', (tester) async {
      await generateWidget(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizationsEn().settings__save));
      await tester.pumpAndSettle();

      expect(find.text(AppLocalizationsEn().settings__title), findsOneWidget);
      expect(find.text(AppLocalizationsEn().home__title), findsNothing);
    });

    testWidgets('font size selector changes the selected option', (
      tester,
    ) async {
      final settingsController = await generateWidget(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(settingsController.fontSize, AppFontSizeOption.medium);
      expect(_settingsTitleFontSize(tester), 32);
      expect(
        find.widgetWithText(
          FilledButton,
          AppLocalizationsEn().settings__fontSizeMedium,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(AppLocalizationsEn().settings__fontSizeLarge));
      await tester.pumpAndSettle();

      expect(settingsController.fontSize, AppFontSizeOption.large);
      expect(_settingsTitleFontSize(tester), 36);
      expect(
        find.widgetWithText(
          FilledButton,
          AppLocalizationsEn().settings__fontSizeLarge,
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          FilledButton,
          AppLocalizationsEn().settings__fontSizeMedium,
        ),
        findsNothing,
      );

      await tester.tap(find.text(AppLocalizationsEn().settings__fontSizeXl));
      await tester.pumpAndSettle();

      expect(settingsController.fontSize, AppFontSizeOption.xl);
      expect(_settingsTitleFontSize(tester), 40);
      expect(
        find.widgetWithText(
          FilledButton,
          AppLocalizationsEn().settings__fontSizeXl,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'language dropdown lists supported languages and is selectable',
      (tester) async {
        await generateWidget(tester);

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        final dropdownFinder = find.byType(DropdownButton<Locale>);
        final dropdown = tester.widget<DropdownButton<Locale>>(dropdownFinder);

        expect(
          dropdown.items,
          hasLength(AppLocalizations.supportedLocales.length),
        );
        expect(
          dropdown.items!.map((item) => item.value),
          containsAll(AppLocalizations.supportedLocales),
        );
        expect(dropdown.value, const Locale('en'));

        dropdown.onChanged!(const Locale('nl'));
        await tester.pumpAndSettle();

        final selectedDropdown = tester.widget<DropdownButton<Locale>>(
          dropdownFinder,
        );

        expect(selectedDropdown.value, const Locale('nl'));
        expect(find.text(AppLocalizationsNl().settings__title), findsOneWidget);
        expect(find.text(AppLocalizationsEn().settings__title), findsNothing);
      },
    );

    testWidgets('model list changes the selected model', (tester) async {
      await generateWidget(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings-model-selected-user2')),
        findsOneWidget,
      );

      await tester.tap(find.text(AppLocalizationsEn().settings__modelUser1));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings-model-selected-user1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-model-selected-user2')),
        findsNothing,
      );
    });

    testWidgets('bottom back button returns to home page', (tester) async {
      await generateWidget(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizationsEn().settings__back));
      await tester.pumpAndSettle();

      expect(find.text(AppLocalizationsEn().home__title), findsOneWidget);
      expect(find.text(AppLocalizationsEn().settings__title), findsNothing);
    });
  });
}

double? _settingsTitleFontSize(WidgetTester tester) {
  final title = tester.widget<Text>(
    find.text(AppLocalizationsEn().settings__title),
  );
  return title.style?.fontSize;
}
