import 'dart:async';

import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_runtime_factory.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
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
    : _loadRuntime = loadRuntime ?? const AsrRuntimeFactory().create;

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
      notifyListeners();
    } catch (error) {
      _error = error;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    try {
      await previousRuntime?.dispose();
    } catch (error) {
      debugPrint('Error disposing previous ASR runtime: $error');
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
