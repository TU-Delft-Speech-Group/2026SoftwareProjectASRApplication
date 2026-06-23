import 'dart:collection';

import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/data/services/remote/remote_model_service.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/main.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/services/pipeline/asr_runtime_controller.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../testing/fakes/services/pipeline/fake_asr_runtime.dart';
@GenerateNiceMocks([
  MockSpec<ModelPackageService>(),
  MockSpec<RemoteModelService>(),
  MockSpec<ModelRepository>(),
])
import 'delete_model_navigation_test.mocks.dart';

// exercises the wiring in main.dart, unlike settings_model_list_test.dart
// (which fakes onModelDeleted), this drives MainApp end to end so the
// AsrRuntimeController.close() + _handleAsrRuntimeChanged fix for deleting the
// last installed model is covered.
void main() {
  late MockModelPackageService packageService;
  late MockRemoteModelService remoteService;
  late MockModelRepository modelRepo;
  late AsrRuntimeController asrController;
  late ModelInstallController installController;
  late SettingsRepository settingsRepository;
  late List<String> availableModels;

  setUp(() {
    availableModels = ['only-model'];
    packageService = MockModelPackageService();
    remoteService = MockRemoteModelService();
    modelRepo = MockModelRepository();
    provideDummy<Result<void>>(Result.ok(null));
    provideDummy<Result<ModelList>>(
      Result.ok(ModelList(modelNames: UnmodifiableListView(<String>[]))),
    );

    when(modelRepo.getModelList()).thenAnswer(
      (_) => ModelList(modelNames: UnmodifiableListView(availableModels)),
    );
    when(modelRepo.deleteModel('only-model')).thenAnswer((_) async {
      availableModels = [];
      return Result.ok(null);
    });

    asrController = AsrRuntimeController(
      loadRuntime: (_) async => FakeAsrRuntime(),
    );

    settingsRepository = SettingsRepository(
      save: (String k, String v) async => Mock(),
      remove: (String k) async => Mock(),
      preferences: {'settings_model': 'only-model'},
    );

    installController = ModelInstallController(
      packageService: packageService,
      remoteService: remoteService,
      modelRepo: modelRepo,
      settingsRepository: settingsRepository,
    );
  });

  testWidgets(
    'deleting the only installed model clears the active runtime and shows '
    'the no-model state on the home page',
    (tester) async {
      await asrController.loadModel('only-model');

      await tester.pumpWidget(
        MainApp(
          asrController: asrController,
          installController: installController,
          settingsRepository: settingsRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(asrController.runtime, isNotNull);
      expect(
        find.text(AppLocalizationsEn().home__noModelSelected),
        findsNothing,
      );

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('settings-model-delete-only-model')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizationsEn().settings__deleteModel));
      await tester.pumpAndSettle();

      expect(asrController.runtime, isNull);

      await tester.tap(find.text(AppLocalizationsEn().settings__back));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().home__noModelSelected),
        findsOneWidget,
      );
    },
  );
}
