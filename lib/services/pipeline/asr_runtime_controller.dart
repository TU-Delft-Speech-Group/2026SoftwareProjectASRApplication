import 'dart:async';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

// Added to make testing easier by allowing injection of a fake runtime loader
typedef AsrRuntimeLoader = Future<AsrRuntime> Function(String modelName);

/// Manages the active ASR runtime and supports model switching
///
/// The controller keeps the currently loaded [runtime], exposes loading/error
/// state for model selection UI, and swaps runtimes only after a new model has
/// loaded successfully. If a future model switch fails, the previous runtime is
/// left active so transcription can continue with the old model
class AsrRuntimeController extends ChangeNotifier {
  AsrRuntimeController({required AsrRuntimeLoader loadRuntime})
    : _loadRuntime = loadRuntime;

  final AsrRuntimeLoader _loadRuntime;

  AsrRuntime? _runtime;
  String? _modelName;
  Object? _error;
  bool _isLoading = false;

  /// Runtime for the currently selected and loaded model, or null if no model is loaded
  AsrRuntime? get runtime => _runtime;

  /// Model name that produced [runtime].
  String? get modelName => _modelName;

  /// Deprecated compatibility getter for callers that still read `model`.
  @Deprecated('Use modelName instead.')
  String? get model => _modelName;

  /// Last model loading error, cleared before each new load attempt
  Object? get error => _error;

  /// Whether a model is currently being loaded
  bool get isLoading => _isLoading;

  /// Whether a runtime is ready for transcription
  bool get hasRuntime => _runtime != null;

  /// Loads [modelName] and makes it the active runtime after initialization.
  Future<void> loadModel(String modelName) async {
    dev.log('loading model: $modelName', name: 'AsrRuntimeController');
    _isLoading = true;
    _error = null;
    notifyListeners();

    AsrRuntime? previousRuntime;
    try {
      final nextRuntime = await _loadRuntime(modelName);
      previousRuntime = _runtime;
      _runtime = nextRuntime;
      _modelName = modelName;
      _isLoading = false;
      dev.log('model loaded successfully', name: 'AsrRuntimeController');
      notifyListeners();
    } catch (error) {
      _error = error;
      _isLoading = false;
      dev.log(
        'model load failed: $error',
        name: 'AsrRuntimeController',
        level: 900,
      );
      notifyListeners();
      rethrow;
    }

    try {
      await previousRuntime?.dispose();
    } catch (error) {
      dev.log(
        'Error disposing previous ASR runtime: $error',
        name: 'AsrRuntimeController',
        level: 900,
      );
    }
  }

  /// Updates the active model name when the installed model directory is
  /// renamed but the already loaded runtime can stay in place.
  void renameActiveModel(String newName) {
    if (_modelName == newName) return;

    _modelName = newName;
    dev.log('renamed active model to: $newName', name: 'AsrRuntimeController');
    notifyListeners();
  }

  Future<void> close() async {
    final runtime = _runtime;
    _runtime = null;
    _modelName = null;
    _isLoading = false;
    notifyListeners();
    await runtime?.dispose();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
