import 'dart:collection';

import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/l10n/generated/app_localizations_nl.dart';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

@GenerateNiceMocks([MockSpec<ModelInstallController>()])
@GenerateNiceMocks([
  MockSpec<RecorderService>(),
  MockSpec<AudioRecorder>(),
  MockSpec<RecordingCoordinator>(),
])
import 'settings_navigation_test.mocks.dart';

void main() {
  late MockModelInstallController mockModelInstallController;

  setUp(() {
    mockModelInstallController = MockModelInstallController();

    final modelNames = ['model1', 'model2'];

    Result<ModelList> modelListResult() {
      return Result.ok(ModelList(modelNames: UnmodifiableListView(modelNames)));
    }

    provideDummy(modelListResult());
    provideDummy<Result<void>>(Result<void>.ok(null));
    when(
      mockModelInstallController.getModelList(),
    ).thenAnswer((_) async => modelListResult());

    String? activeModel = 'model2';
    when(
      mockModelInstallController.activeModelName,
    ).thenAnswer((_) => activeModel);
    when(mockModelInstallController.selectModel(any)).thenAnswer((inv) {
      activeModel = inv.positionalArguments[0];
      mockModelInstallController.notifyListeners();
    });
    when(mockModelInstallController.renameModel(any, any)).thenAnswer((
      inv,
    ) async {
      final currentName = inv.positionalArguments[0] as String;
      final newName = inv.positionalArguments[1] as String;
      final index = modelNames.indexOf(currentName);
      if (index != -1) {
        modelNames[index] = newName;
      }
      if (activeModel == currentName) {
        activeModel = newName;
      }
      return Result.ok(null);
    });
  });

  Future<SettingsRepository> generateWidget(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final settingsRepository = SettingsRepository(
      save: (String k, String v) async => Mock(),
      preferences: {},
    );

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
                viewModel: HomeViewModel(
                  recorder: MockAudioRecorder(),
                  recorderService: MockRecorderService(),
                  coordinator: MockRecordingCoordinator(),
                ),
                modelController: mockModelInstallController,
              ),
            ),
          );
        },
      ),
    );

    return settingsRepository;
  }

  Future<SettingsRepository> openSettingsPage(WidgetTester tester) async {
    final settingsRepository = await generateWidget(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    return settingsRepository;
  }

  tearDown(() {
    mockModelInstallController.dispose();
  });

  group('Settings navigation', () {
    testWidgets('menu button shows the navigation to settings', (tester) async {
      await openSettingsPage(tester);

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
      expect(find.text(AppLocalizationsEn().settings__back), findsOneWidget);
    });

    testWidgets('font size selector changes the selected option', (
      tester,
    ) async {
      final settingsRepository = await openSettingsPage(tester);

      final dropdownFinder = find.byType(DropdownButton<AppFontSizeOption>);
      DropdownButton<AppFontSizeOption> dropdown() =>
          tester.widget<DropdownButton<AppFontSizeOption>>(dropdownFinder);

      expect(settingsRepository.getFontsize(), AppFontSizeOption.medium);
      expect(_settingsTitleFontSize(tester), 32);
      expect(dropdown().value, AppFontSizeOption.medium);

      dropdown().onChanged!(AppFontSizeOption.large);
      await tester.pumpAndSettle();

      expect(settingsRepository.getFontsize(), AppFontSizeOption.large);
      expect(_settingsTitleFontSize(tester), 36);
      expect(dropdown().value, AppFontSizeOption.large);

      dropdown().onChanged!(AppFontSizeOption.xl);
      await tester.pumpAndSettle();

      expect(settingsRepository.getFontsize(), AppFontSizeOption.xl);
      expect(_settingsTitleFontSize(tester), 40);
      expect(dropdown().value, AppFontSizeOption.xl);
    });

    testWidgets('split screen toggle changes the setting', (tester) async {
      final settingsRepository = await openSettingsPage(tester);

      expect(settingsRepository.getSplitscreen(), isFalse);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(Switch), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('settings-split-screen-toggle')),
      );
      await tester.pumpAndSettle();

      expect(settingsRepository.getSplitscreen(), isTrue);

      await tester.tap(
        find.byKey(const ValueKey('settings-split-screen-toggle')),
      );
      await tester.pumpAndSettle();

      expect(settingsRepository.getSplitscreen(), isFalse);
    });

    testWidgets(
      'language dropdown lists supported languages and is selectable',
      (tester) async {
        await openSettingsPage(tester);

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
      await openSettingsPage(tester);

      await tester.tap(find.text('model1'));
      await tester.pumpAndSettle();

      verify(mockModelInstallController.selectModel('model1')).called(1);
    });

    testWidgets('model list renames a model', (tester) async {
      await openSettingsPage(tester);

      await tester.tap(
        find.byKey(const ValueKey('settings-model-rename-model1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().settings__renameModel),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'model one');
      await tester.tap(find.text(AppLocalizationsEn().settings__rename));
      await tester.pumpAndSettle();

      verify(
        mockModelInstallController.renameModel('model1', 'model one'),
      ).called(1);
      expect(find.text('model one'), findsOneWidget);
      expect(find.text('model1'), findsNothing);
      expect(
        find.text(AppLocalizationsEn().settings__modelRenamed('model one')),
        findsOneWidget,
      );
    });

    testWidgets('bottom back button returns to home page', (tester) async {
      await openSettingsPage(tester);

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
