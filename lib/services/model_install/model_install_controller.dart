import 'dart:io';

import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/data/services/remote/remote_model_service.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/exceptions/model/invalid_model_file_exception.dart';
import 'package:asr_application/utils/decide_active_model.dart';
import 'package:asr_application/utils/result.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

enum ModelInstallControllerState { idle, downloadAndInstall, pickAndInstall }

typedef ModelFilePicker = Future<String?> Function();

/// Owns the workflow for installing a user-picked .asrmodel and tracking which
/// model the app should load. Lifted out of main.dart so the widget tree can
/// drive installs by talking to a controller rather than a callback closure.
class ModelInstallController extends ChangeNotifier {
  ModelInstallController({
    required ModelPackageService packageService,
    required RemoteModelService remoteService,
    required ModelRepository modelRepo,
    required SettingsRepository settingsRepository,
    ModelFilePicker? filePicker,
    ValueChanged<String>? onActiveModelRenamed,
  }) : _packageService = packageService,
       _remoteService = remoteService,
       _modelRepo = modelRepo,
       _settingsRepository = settingsRepository,
       _filePicker = filePicker ?? _defaultFilePicker,
       _onActiveModelRenamed = onActiveModelRenamed;

  final ModelPackageService _packageService;
  final RemoteModelService _remoteService;
  final ModelRepository _modelRepo;
  final ModelFilePicker _filePicker;
  final SettingsRepository _settingsRepository;

  /// Keeps the loaded runtime label in sync when the active model directory is
  /// renamed, without reloading the model files.
  final ValueChanged<String>? _onActiveModelRenamed;

  String? get activeModelName => _settingsRepository.getModelName();

  ModelList getModelList() => _modelRepo.getModelList();

  ModelInstallControllerState _installStatus = .idle;
  ModelInstallControllerState get installStatus => _installStatus;

  Future<void> selectModel(String modelName) async {
    if (activeModelName == modelName) return;

    await _settingsRepository.setModelName(modelName);
    debugPrint('Switched active model to: $modelName');
    notifyListeners();
  }

  Future<Result<void>> renameModel(String currentName, String newName) async {
    final normalizedName = newName.trim();
    if (currentName == normalizedName) return Result.ok(null);

    final result = await _modelRepo.renameModel(currentName, normalizedName);

    if (result is Error<void>) {
      return result;
    }

    if (activeModelName == currentName) {
      await _settingsRepository.setModelName(normalizedName);
      _onActiveModelRenamed?.call(normalizedName);
      debugPrint('Renamed active model to: $normalizedName');
    } else {
      debugPrint('Renamed model $currentName to: $normalizedName');
    }

    notifyListeners();
    return result;
  }

  Future<Result<void>> downloadAndInstall(String modelUrl) async {
    if (_installStatus != .idle) {
      // this is an invalid state of the app, not user error, therefor an exception instead of error result.
      throw Exception(
        "[modelInstallController::downloadAndInstall] request to install while not idle.",
      );
    }
    _installStatus = .downloadAndInstall;
    notifyListeners();

    final result = await _remoteService.downloadModel(modelUrl);

    File downloadFile;
    switch (result) {
      case Ok():
        downloadFile = result.value;
        break;
      case Error():
        _installStatus = .idle;
        notifyListeners();
        return result;
    }

    try {
      await _packageService.install(downloadFile);
      await _modelRepo.retrieveModels();
      return Result.ok(null);
    } catch (e) {
      debugPrint(e.toString());
      return Result.error(
        Exception('Failed to install model: ${e.toString()}.'),
      );
    } finally {
      try {
        await downloadFile.delete();
      } catch (_) {}
      _installStatus = .idle;
      notifyListeners();
    }
  }

  /// Prompts the user for an .asrmodel file and installs it. The result
  /// value is false if the user cancelled the picker without choosing a
  /// file, true if a model was installed. Throws on install failure.
  Future<Result<bool>> pickAndInstall() async {
    // this is an invalid state of the app, not user error, therefor an exception instead of error result.
    if (_installStatus != .idle) {
      throw Exception(
        "[modelInstallController::pickAndInstall] request to install while not idle.",
      );
    }
    _installStatus = .pickAndInstall;
    notifyListeners();

    final path = await _filePicker();
    if (path == null) {
      _installStatus = .idle;
      notifyListeners();
      return Result.ok(false);
    }

    // Android (and a widened file-type filter elsewhere) lets the user pick any
    // file, so verify the extension before trying to install and surface a
    // clear error when it is wrong.
    if (!path.toLowerCase().endsWith(ModelPackageService.extension)) {
      debugPrint('Picked file is not an .asrmodel: $path');
      _installStatus = .idle;
      notifyListeners();
      return Result.error(InvalidModelFileException(path));
    }

    debugPrint('Installing picked .asrmodel: $path');
    try {
      await _packageService.install(File(path));
      await _modelRepo.retrieveModels();
      return Result.ok(true);
    } catch (e) {
      debugPrint(e.toString());
      return Result.error(
        Exception('Failed to install model: ${e.toString()}.'),
      );
    } finally {
      _installStatus = .idle;
      notifyListeners();
    }
  }

  // Deletes [modelName] from disk. If it was the active model, switches to
  // another installed model when one remains, or clears the active model
  // entirely when none do.
  Future<Result<void>> deleteModel(String modelName) async {
    final result = await _modelRepo.deleteModel(modelName);
    if (result case Error()) return result;

    if (activeModelName == modelName) {
      final availableModels = _modelRepo.getModelList();
      final newActiveModel = decideActiveModel(availableModels, modelName);
      await _settingsRepository.setModelName(newActiveModel);
      debugPrint('Active model deleted; switched to: $newActiveModel');
    }

    notifyListeners();
    return Result.ok(null);
  }

  // The check for Android exists as custom file extensions are allowed for Android currently.
  static Future<String?> _defaultFilePicker() async {
    final picked = Platform.isAndroid
        ? await FilePicker.platform.pickFiles()
        : await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['asrmodel'],
          );
    if (picked == null || picked.files.isEmpty) return null;
    return picked.files.single.path;
  }
}
