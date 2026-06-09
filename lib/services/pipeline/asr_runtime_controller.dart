import 'dart:async';

import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_runtime_factory.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

// Added to make testing easier by allowing injection of a fake runtime loader
typedef AsrRuntimeLoader = Future<AsrRuntime> Function(AsrModelConfig model);

/// Manages the active ASR runtime and supports model switching
///
/// The controller keeps the currently loaded [runtime], exposes loading/error
/// state for model selection UI, and swaps runtimes only after a new model has
/// loaded successfully. If a future model switch fails, the previous runtime is
/// left active so transcription can continue with the old model
class AsrRuntimeController extends ChangeNotifier {
  AsrRuntimeController({AsrRuntimeLoader? loadRuntime})
    : _loadRuntime = loadRuntime ?? _defaultLoadRuntime;

  static Future<AsrRuntime> _defaultLoadRuntime(AsrModelConfig model) {
    if (model is! AsrAssetModelConfig) {
      throw ArgumentError(
        'Default loader only supports AsrAssetModelConfig. '
        'Pass a custom loadRuntime to load installed (file-based) models.',
      );
    }
    return const AsrRuntimeFactory().create(model);
  }

  final AsrRuntimeLoader _loadRuntime;

  AsrRuntime? _runtime;
  AsrModelConfig? _model;
  Object? _error;
  bool _isLoading = false;

  /// Runtime for the currently selected and loaded model, or null if no model is loaded
  AsrRuntime? get runtime => _runtime;

  /// Model configuration that produced [runtime]
  AsrModelConfig? get model => _model;

  /// Last model loading error, cleared before each new load attempt
  Object? get error => _error;

  /// Whether a model is currently being loaded
  bool get isLoading => _isLoading;

  /// Whether a runtime is ready for transcription
  bool get hasRuntime => _runtime != null;

  /// Loads [model] and makes it the active runtime after initialization
  Future<void> loadModel(AsrModelConfig model) async {
    final encoderDescription = model is AsrAssetModelConfig
        ? model.encoderAsset
        : '<installed model>';
    dev.log(
      'loading model: encoder=$encoderDescription',
      name: 'AsrRuntimeController',
    );
    _isLoading = true;
    _error = null;
    notifyListeners();

    AsrRuntime? previousRuntime;
    try {
      final nextRuntime = await _loadRuntime(model);
      previousRuntime = _runtime;
      _runtime = nextRuntime;
      _model = model;
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

  Future<void> close() async {
    final runtime = _runtime;
    _runtime = null;
    _model = null;
    _isLoading = false;
    await runtime?.dispose();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
