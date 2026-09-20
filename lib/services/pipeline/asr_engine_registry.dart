import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/services/pipeline/asr_engine_factory.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';

/// Registry of available ASR engine factories, keyed by engine id.
///
/// Adding a new engine is one step: register it here. No changes to main.dart
/// or the routing logic.
class AsrEngineRegistry {
  AsrEngineRegistry(List<AsrEngineFactory> engines)
      : _engines = {for (final e in engines) e.engineId: e};

  final Map<String, AsrEngineFactory> _engines;

  /// Known engine ids, for diagnostics.
  Iterable<String> get supportedEngines => _engines.keys;

  /// Creates a runtime for [model], routing to the correct engine based on
  /// the model's metadata. Falls back to "espnet" for legacy models without
  /// an engine field.
  Future<AsrRuntime> createRuntime(Model model) {
    final engineId = model.metadata?.engine ?? 'espnet';
    final factory = _engines[engineId];
    if (factory == null) {
      throw StateError(
        'No engine registered for "$engineId". '
        'Available: ${_engines.keys.join(", ")}',
      );
    }
    return factory.createRuntime(model);
  }
}
