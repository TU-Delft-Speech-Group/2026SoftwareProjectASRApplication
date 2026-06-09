import 'dart:io';

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';

Future<ModelInstallController> buildFakeModelController({
  List<String> modelNames = const ['model1', 'model2'],
  String activeModelName = 'model2',
}) async {
  const config = LocalModelStorageConfig();
  final localModelService = FakeLocalModelService(modelNames);
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
    initialModelName: activeModelName,
  );
}

class FakeLocalModelService extends LocalModelService {
  FakeLocalModelService(this.modelNames)
    : super(config: const LocalModelStorageConfig());

  final List<String> modelNames;

  @override
  Future<List<String>> getAvailableModels() async => modelNames;

  @override
  Future<Directory> getModelDirectory(String modelName) async =>
      Directory(modelName);
}
