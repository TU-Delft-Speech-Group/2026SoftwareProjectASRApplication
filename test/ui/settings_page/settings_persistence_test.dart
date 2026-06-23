import 'dart:collection';

import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/data/services/remote/remote_model_service.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
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

@GenerateNiceMocks([
  MockSpec<RecorderService>(),
  MockSpec<AudioRecorder>(),
  MockSpec<RecordingCoordinator>(),
  MockSpec<ModelPackageService>(),
  MockSpec<RemoteModelService>(),
  MockSpec<ModelRepository>(),
  MockSpec<SettingsRepository>(),
])
import 'settings_persistence_test.mocks.dart';

void main() {
  late ModelInstallController installController;

  late MockModelPackageService mockModelPackageService;
  late MockRemoteModelService mockRemoteModelService;
  late MockModelRepository mockModelRepository;
  late MockSettingsRepository mockSettingsRepository;

  final modelNames = ['model1', 'model2'];
  ModelList modelListResult() {
    return ModelList(modelNames: UnmodifiableListView(modelNames));
  }

  setUp(() {
    mockModelPackageService = MockModelPackageService();
    mockRemoteModelService = MockRemoteModelService();

    provideDummyBuilder<ModelList>((obj, inv) => modelListResult());
    provideDummy<Result<void>>(Result.ok(null));
    mockModelRepository = MockModelRepository();
    when(
      mockModelRepository.getModelList(),
    ).thenAnswer((_) => modelListResult());

    String activeModel = 'model1';
    mockSettingsRepository = MockSettingsRepository();
    when(mockSettingsRepository.getModelName()).thenAnswer((_) => activeModel);
    when(mockSettingsRepository.setModelName(any)).thenAnswer((_) async => {});
    when(
      mockSettingsRepository.getLocale(),
    ).thenAnswer((_) => Locale.fromSubtags(languageCode: 'en'));
    when(mockSettingsRepository.setLocale(any)).thenAnswer((_) async => {});
    when(
      mockSettingsRepository.getFontsize(),
    ).thenAnswer((_) => AppFontSizeOption.medium);
    when(mockSettingsRepository.setFontsize(any)).thenAnswer((_) async => {});
    when(mockSettingsRepository.getSplitscreen()).thenAnswer((_) => false);
    when(
      mockSettingsRepository.setSplitscreen(any),
    ).thenAnswer((_) async => {});

    installController = ModelInstallController(
      packageService: mockModelPackageService,
      remoteService: mockRemoteModelService,
      modelRepo: mockModelRepository,
      settingsRepository: mockSettingsRepository,
    );
  });

  Future<void> generateWidget(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: mockSettingsRepository,
        builder: (context, child) {
          return AppSettingsScope(
            settings: mockSettingsRepository,
            child: MaterialApp(
              locale: mockSettingsRepository.getLocale(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(fontFamily: ThemeFontFamily().arial),
              home: HomePage(
                viewModel: HomeViewModel(
                  recorder: MockAudioRecorder(),
                  recorderService: MockRecorderService(),
                  coordinator: MockRecordingCoordinator(),
                ),
                modelController: installController,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> openSettingsPage(WidgetTester tester) async {
    await generateWidget(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
  }

  tearDown(() {
    installController.dispose();
  });

  group('Settings persistence', () {
    testWidgets('font size selection is persisted', (tester) async {
      await openSettingsPage(tester);
      AppFontSizeOption expected = .xl;

      final dropdownFinder = find.byType(DropdownButton<AppFontSizeOption>);
      DropdownButton<AppFontSizeOption> dropdown() =>
          tester.widget<DropdownButton<AppFontSizeOption>>(dropdownFinder);

      dropdown().onChanged!(expected);
      await tester.pumpAndSettle();

      verify(mockSettingsRepository.setFontsize(expected)).called(1);
    });

    testWidgets('split screen toggle is persisted', (tester) async {
      await openSettingsPage(tester);
      bool expected = !mockSettingsRepository.getSplitscreen();

      await tester.tap(
        find.byKey(const ValueKey('settings-split-screen-toggle')),
      );
      await tester.pumpAndSettle();

      verify(mockSettingsRepository.setSplitscreen(expected)).called(1);
    });

    testWidgets('locale selection is persisted', (tester) async {
      await openSettingsPage(tester);
      Locale expected = Locale('nl');

      final dropdownFinder = find.byType(DropdownButton<Locale>);
      final dropdown = tester.widget<DropdownButton<Locale>>(dropdownFinder);

      expect(dropdown.value, const Locale('en'));

      dropdown.onChanged!(expected);
      await tester.pumpAndSettle();

      verify(mockSettingsRepository.setLocale(expected)).called(1);
    });

    testWidgets('model selection is persisted', (tester) async {
      await openSettingsPage(tester);

      await tester.tap(find.text('model2'));
      await tester.pumpAndSettle();

      verify(mockSettingsRepository.setModelName('model2')).called(1);
    });

    testWidgets('active model renaming is persisted', (tester) async {
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

      verify(mockSettingsRepository.setModelName('model one')).called(1);
    });
  });
}
