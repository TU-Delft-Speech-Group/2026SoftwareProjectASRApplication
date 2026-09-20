import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';

/// Contract that every ASR engine (ESPnet, Whisper, future engines) must
/// implement. The runtime controller uses the registry to look up the right
/// factory by engine name, then calls [createRuntime] with the installed model.
abstract interface class AsrEngineFactory {
  /// The engine identifier as written in manifest.json (e.g. "espnet", "whisper").
  String get engineId;

  /// Creates a fully initialized [AsrRuntime] ready for streaming transcription.
  Future<AsrRuntime> createRuntime(Model model);
}
