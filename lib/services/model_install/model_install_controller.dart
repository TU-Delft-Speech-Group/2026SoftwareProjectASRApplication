import 'dart:io';

import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/data/services/remote/remote_model_service.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
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
    String? initialModelName,
    ModelFilePicker? filePicker,
    ValueChanged<String>? onActiveModelRenamed,
  }) : _packageService = packageService,
       _remoteService = remoteService,
       _modelRepo = modelRepo,
       _activeModelName = initialModelName,
       _filePicker = filePicker ?? _defaultFilePicker,
       _onActiveModelRenamed = onActiveModelRenamed;

  final ModelPackageService _packageService;
  final RemoteModelService _remoteService;
  final ModelRepository _modelRepo;
  final ModelFilePicker _filePicker;

  /// Keeps the loaded runtime label in sync when the active model directory is
  /// renamed, without reloading the model files.
  final ValueChanged<String>? _onActiveModelRenamed;

  String? _activeModelName;
  String? get activeModelName => _activeModelName;

  Future<Result<ModelList>> getModelList() => _modelRepo.getModelList();

  ModelInstallControllerState _installStatus = .idle;
  ModelInstallControllerState get installStatus => _installStatus;

  void selectModel(String modelName) {
    if (_activeModelName == modelName) return;

    _activeModelName = modelName;
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

    if (_activeModelName == currentName) {
      _activeModelName = normalizedName;
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

  /// Prompts the user for an .asrmodel file, installs it, and switches the
  /// active model. Returns the new model name, or null if the user cancelled.
  /// Throws on install failure.
  Future<Result<void>> pickAndInstall() async {
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
      return Result.ok(null);
    }

    debugPrint('Installing picked .asrmodel: $path');
    try {
      await _packageService.install(File(path));
      await _modelRepo.retrieveModels();
      return Result.ok(null);
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
