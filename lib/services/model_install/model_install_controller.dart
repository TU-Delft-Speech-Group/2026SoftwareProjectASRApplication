import 'dart:io';

import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/utils/result.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

typedef ModelFilePicker = Future<String?> Function();

/// Owns the workflow for installing a user-picked .asrmodel and tracking which
/// model the app should load. Lifted out of main.dart so the widget tree can
/// drive installs by talking to a controller rather than a callback closure.
class ModelInstallController extends ChangeNotifier {
  ModelInstallController({
    required ModelPackageService packageService,
    required ModelRepository modelRepo,
    required String initialModelName,
    ModelFilePicker? filePicker,
  }) : _packageService = packageService,
       _modelRepo = modelRepo,
       _activeModelName = initialModelName,
       _filePicker = filePicker ?? _defaultFilePicker;

  final ModelPackageService _packageService;
  final ModelRepository _modelRepo;
  final ModelFilePicker _filePicker;
  String _activeModelName;

  String get activeModelName => _activeModelName;

  Future<Result<ModelList>> getModelList() => _modelRepo.getModelList();

  void selectModel(String modelName) {
    if (_activeModelName == modelName) return;

    _activeModelName = modelName;
    debugPrint('Switched active model to: $modelName');
    notifyListeners();
  }

  /// Prompts the user for an .asrmodel file, installs it, and switches the
  /// active model. Returns the new model name, or null if the user cancelled.
  /// Throws on install failure.
  Future<String?> pickAndInstall() async {
    final path = await _filePicker();
    if (path == null) return null;

    debugPrint('Installing picked .asrmodel: $path');
    final modelName = await _packageService.install(File(path));
    await _modelRepo.retrieveModels();
    selectModel(modelName);
    return modelName;
  }

  static Future<String?> _defaultFilePicker() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['asrmodel'],
    );
    if (picked == null || picked.files.isEmpty) return null;
    return picked.files.single.path;
  }
}
