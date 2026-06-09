import 'dart:io';

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/domain/models/model/model_metadata.dart';
import 'package:asr_application/main.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_runtime.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/settings_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';
import 'package:snaptest/snaptest.dart';
import '../../../testing/fakes/services/pipeline/fake_asr_runtime.dart';

@GenerateNiceMocks([MockSpec<AudioRecorder>()])
import 'regression_test.mocks.dart';

void main() {
  late AsrRuntimeController asrController;
  late AsrRuntime fakeRuntime;
  late HomeViewModel homeViewModel;
  late MockAudioRecorder mockRecorder;
  late ModelInstallController modelController;

  setUp(() async {
    fakeRuntime = FakeAsrRuntime();
    asrController = AsrRuntimeController(loadRuntime: (_) async => fakeRuntime);
    final modelMetadata = ModelMetadata(
      blankId: 0,
      sosEosId: 1,
      suppressedIds: {0, 1, 2},
      unkId: 2,
    );
    await asrController.loadModel(AsrModelConfig.fromMetadata(modelMetadata));

    mockRecorder = MockAudioRecorder();
    when(mockRecorder.hasPermission()).thenAnswer((_) async => true);

    homeViewModel = HomeViewModel(recorder: mockRecorder);
    modelController = await _buildModelController();
  });

  tearDown(() {
    homeViewModel.dispose();
  });

  Future<void> loadScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MainApp(
        asrController: asrController,
        homeViewModel: homeViewModel,
        installController: modelController,
      ),
    );
    await tester.tap(find.byType(SettingsButton));
    await tester.pumpAndSettle();
  }

  snapTest('Settings page - initial', (tester) async {
    await loadScreen(tester);

    await snap(name: 'settings_initial', matchToGolden: true);
  });

  snapTest('Settings page - larger text', (tester) async {
    await loadScreen(tester);

    await tester.tap(find.byType(FilledButton).at(0));

    await snap(name: 'settings_larger', matchToGolden: true);
  });

  snapTest('Settings page - XL text', (tester) async {
    await loadScreen(tester);

    await tester.tap(find.byType(FilledButton).at(1));

    await snap(name: 'settings_xl', matchToGolden: true);
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
