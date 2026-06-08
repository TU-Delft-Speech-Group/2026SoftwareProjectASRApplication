import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/domain/models/model/model_files.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/domain/models/model/model_metadata.dart';
import 'package:asr_application/utils/result.dart';
import 'package:asr_application/exceptions/model/model_not_found_exception.dart';

class ModelRepository {
  ModelRepository({
    required LocalModelService localModelService,
    required LocalModelStorageConfig config,
  }) : _localModelService = localModelService,
       _config = config;

  final LocalModelStorageConfig _config;
  final LocalModelService _localModelService;
  final _availableModels = List<String>.empty(growable: true);

  Future<Result<void>> retrieveModels() async {
    try {
      _availableModels.clear();
      _availableModels.addAll(await _localModelService.getAvailableModels());
      return Result.ok(null);
    } catch (e) {
      return Result.error(Exception('Failed to get available models: $e'));
    }
  }

  Future<Result<ModelList>> getModelList() async {
    return Result.ok(
      ModelList(modelNames: UnmodifiableListView(_availableModels)),
    );
  }

  Future<Result<Model>> getModel(String modelName) async {
    if (!_availableModels.contains(modelName)) {
      return Result.error(ModelNotFoundException());
    }

    Directory modelDirectory = await _localModelService.getModelDirectory(
      modelName,
    );

    final decoderFile = File(
      p.join(modelDirectory.path, _config.decoderFilePath),
    );
    ModelFiles modelFiles = ModelFiles(
      ctcPath: File(p.join(modelDirectory.path, _config.ctcFilePath)),
      encoderPath: File(p.join(modelDirectory.path, _config.encoderFilePath)),
      decoderPath: decoderFile.existsSync() ? decoderFile : null,
      vocabPath: File(p.join(modelDirectory.path, _config.vocabFilePath)),
    );

    final metadata = await _readMetadata(modelDirectory);

    return Result.ok(
      Model(name: modelName, files: modelFiles, metadata: metadata),
    );
  }

  /// Reads the preserved manifest's vocab metadata, if present. Returns null
  /// for legacy packages with no manifest or no "vocab" block, or if the
  /// manifest is unreadable — loading then falls back to built-in defaults.
  Future<ModelMetadata?> _readMetadata(Directory modelDirectory) async {
    final manifestFile = File(
      p.join(modelDirectory.path, _config.manifestFilePath),
    );
    if (!await manifestFile.exists()) return null;
    try {
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      return ModelMetadata.fromManifest(manifest);
    } catch (_) {
      return null;
    }
  }

  Future<Result<void>> deleteModel(String modelName) async {
    if (!_availableModels.contains(modelName)) {
      return Result.error(ModelNotFoundException());
    }

    try {
      await _localModelService.deleteModel(modelName);
      _availableModels.remove(modelName);
      return Result.ok(null);
    } catch (e) {
      switch (e) {
        case ModelNotFoundException _:
          return Result.error(ModelNotFoundException());
        default:
          return Result.error(Exception('Failed to delete model: $e'));
      }
    }
  }
}
