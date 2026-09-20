import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/services/engines/whisper/whisper_asr_engine.dart';
import 'package:asr_application/services/pipeline/asr_engine_factory.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';

/// Adapts [WhisperAsrEngine] to the universal [AsrEngineFactory] contract.
class WhisperEngineFactory implements AsrEngineFactory {
  const WhisperEngineFactory();

  @override
  String get engineId => 'whisper';

  @override
  Future<AsrRuntime> createRuntime(Model model) {
    return const WhisperAsrEngine().createRuntime(model.files, model.metadata!);
  }
}
