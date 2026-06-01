import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/exceptions/model/model_not_found_exception.dart';
import 'package:path_provider/path_provider.dart';

class LocalModelService {
  LocalModelService({required LocalModelStorageConfig config})
    : _config = config;

  bool _isInitialized = false;

  final LocalModelStorageConfig _config;
  Directory? _modelsRoot;

  Future<List<String>> getAvailableModels() async {
    if (!_isInitialized) {
      await _initialize();
    }

    if (!await _modelsRoot!.exists()) {
      throw Exception('Models root directory does not exist');
    }

    List<FileSystemEntity> modelDirectories = await _modelsRoot!
        .list()
        .toList();
    return modelDirectories
        .whereType<Directory>()
        .where((directory) => _isValidModelDirectory(directory))
        .map((directory) => p.basename(directory.path))
        .toList();
  }

  Future<Directory> getModelDirectory(String modelName) async {
    if (!_isInitialized) {
      await _initialize();
    }

    return _getModelDirectory(modelName);
  }

  Future<void> deleteModel(String modelName) async {
    if (!_isInitialized) {
      await _initialize();
    }

    Directory modelDirectory = _getModelDirectory(modelName);
    if (!await modelDirectory.exists()) {
      throw ModelNotFoundException();
    }

    await modelDirectory.delete(recursive: true);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    Directory appDirectory = await getApplicationDocumentsDirectory();
    _modelsRoot = Directory('${appDirectory.path}/${_config.directory}');

    if (!await _modelsRoot!.exists()) {
      await _modelsRoot!.create();
    }

    _isInitialized = true;
  }

  Directory _getModelDirectory(String modelName) {
    return Directory(p.join(_modelsRoot!.path, modelName));
  }

  bool _isValidModelDirectory(Directory directory) {
    return [
      File(p.join(directory.path, _config.ctcFilePath)),
      File(p.join(directory.path, _config.encoderFilePath)),
      File(p.join(directory.path, _config.vocabFilePath)),
    ].every((file) => file.existsSync());
  }
}
