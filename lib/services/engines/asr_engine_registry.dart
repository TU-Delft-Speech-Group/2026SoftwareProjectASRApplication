import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/services/engines/asr_engine.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';

/// Dispatches installed models to the engine that handles their model type.
final class AsrEngineRegistry {
  AsrEngineRegistry({required Iterable<AsrEngine> engines}) {
    for (final engine in engines) {
      final previous = _enginesByType[engine.modelType];
      if (previous != null) {
        throw ArgumentError.value(
          engine.modelType,
          'engines',
          'Duplicate ASR engine registration',
        );
      }
      _enginesByType[engine.modelType] = engine;
    }
  }

  final Map<String, AsrEngine> _enginesByType = {};

  bool supports(String modelType) => _enginesByType.containsKey(modelType);

  Future<AsrRuntime> createRuntime(Model model) {
    final engine = _enginesByType[model.modelType];
    if (engine == null) {
      throw UnsupportedError('Unsupported ASR model type: ${model.modelType}');
    }
    return engine.createRuntime(model);
  }
}
