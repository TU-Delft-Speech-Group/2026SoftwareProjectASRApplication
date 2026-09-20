import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/services/engines/espnet/espnet_asr_engine.dart';
import 'package:asr_application/services/pipeline/asr_engine_factory.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';

/// Adapts [EspnetAsrEngine] to the universal [AsrEngineFactory] contract.
class EspnetEngineFactory implements AsrEngineFactory {
  const EspnetEngineFactory({EspnetAsrEngine? engine})
      : _engine = engine ?? const EspnetAsrEngine();

  final EspnetAsrEngine _engine;

  @override
  String get engineId => 'espnet';

  @override
  Future<AsrRuntime> createRuntime(Model model) {
    final config = model.metadata != null
        ? AsrModelConfig.fromMetadata(model.metadata!)
        : AsrAssetModelConfig.englishGigaspeech;
    return _engine.createFromModelFiles(model.files, config);
  }
}
