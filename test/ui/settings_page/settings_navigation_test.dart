import 'dart:io';

import 'package:asr_application/app/app_settings_controller.dart';
import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/l10n/generated/app_localizations_nl.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> generateWidget(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final settingsController = AppSettingsController(
      locale: const Locale('en'),
    );
    final modelController = await _buildModelController();

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
              home: HomePage(
                viewModel: HomeViewModel(),
                modelController: modelController,
              ),
            ),
          );
        },
      ),
    );
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
      await generateWidget(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(
          FilledButton,
          AppLocalizationsEn().settings__fontSizeMedium,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(AppLocalizationsEn().settings__fontSizeLarge));
      await tester.pumpAndSettle();

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

      expect(
        find.byKey(const ValueKey('settings-model-selected-model1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-model-selected-model2')),
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

Future<ModelInstallController> _buildModelController() async {
  const config = LocalModelStorageConfig();
  final localModelService = _FakeLocalModelService(['model1', 'model2']);
  final repository = ModelRepository(
    localModelService: localModelService,
    config: config,
  );
  await repository.retrieveModels();

  return ModelInstallController(
    packageService: ModelPackageService(
      localModelService: localModelService,
      config: config,
    ),
    modelRepo: repository,
    initialModelName: 'model2',
  );
}

class _FakeLocalModelService extends LocalModelService {
  _FakeLocalModelService(this.modelNames)
    : super(config: const LocalModelStorageConfig());

  final List<String> modelNames;

  @override
  Future<List<String>> getAvailableModels() async => modelNames;

  @override
  Future<Directory> getModelDirectory(String modelName) async =>
      Directory(modelName);
}
