import 'dart:collection';

import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/l10n/generated/app_localizations_nl.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<ModelInstallController>()])
import 'settings_navigation_test.mocks.dart';

void main() {
  late MockModelInstallController modelInstallController;
  Future<SettingsRepository> generateWidget(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final settingsRepository = SettingsRepository(
      save: (String k, String v) async => Mock(),
      preferences: {},
    );
    modelInstallController = MockModelInstallController();

    provideDummy(
      Result.ok(
        ModelList(modelNames: UnmodifiableListView(['model1', 'model2'])),
      ),
    );

    String activeModel = 'model2';
    provideDummyBuilder<String>((obj, inv) {
      if (inv.memberName == Symbol('activeModelName')) {
        return activeModel;
      }
      return '';
    });

    when(modelInstallController.selectModel(any)).thenAnswer((inv) {
      activeModel = inv.positionalArguments[0];
    });

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: settingsRepository,
        builder: (context, child) {
          return AppSettingsScope(
            settings: settingsRepository,
            child: MaterialApp(
              locale: settingsRepository.getLocale(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(fontFamily: ThemeFontFamily().arial),
              home: HomePage(
                viewModel: HomeViewModel(),
                modelController: modelInstallController,
              ),
            ),
          );
        },
      ),
    );

    return settingsRepository;
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
        find.text(AppLocalizationsEn().settings__splitScreen),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().settings__splitScreenDescription),
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
      expect(find.text('model1'), findsOneWidget);
      expect(find.text('model2'), findsOneWidget);
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
      final settingsRepository = await generateWidget(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(settingsRepository.getFontsize(), AppFontSizeOption.medium);
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

      expect(settingsRepository.getFontsize(), AppFontSizeOption.large);
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

      expect(settingsRepository.getFontsize(), AppFontSizeOption.xl);
      expect(_settingsTitleFontSize(tester), 40);
      expect(
        find.widgetWithText(
          FilledButton,
          AppLocalizationsEn().settings__fontSizeXl,
        ),
        findsOneWidget,
      );
    });

    testWidgets('split screen toggle changes the setting', (tester) async {
      final settingsController = await generateWidget(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(settingsController.getSplitscreen(), isFalse);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(Switch), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('settings-split-screen-toggle')),
      );
      await tester.pumpAndSettle();

      expect(settingsController.getSplitscreen(), isTrue);

      await tester.tap(
        find.byKey(const ValueKey('settings-split-screen-toggle')),
      );
      await tester.pumpAndSettle();

      expect(settingsController.getSplitscreen(), isFalse);
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
        find.byKey(const ValueKey('settings-model-selected-model2')),
        findsOneWidget,
      );

      await tester.tap(find.text('model1'));
      await tester.pumpAndSettle();

      verify(modelInstallController.selectModel('model1')).called(1);
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
