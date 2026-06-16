import 'package:asr_application/services/audio/vad_service.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';

/// Owns the services needed to run one loaded ASR model.
///
/// Runtime construction is engine-specific; UI code should use
/// [transcriptionService] for live transcription and call [dispose] when
/// switching away from this model.
abstract interface class AsrRuntime {
  /// The streaming transcription API used by the home view model.
  AsrTranscriptionService get transcriptionService;

  // VAD service pre-initialised alongside the model; null when the Silero
  // model asset was unavailable and the pipeline falls back to amplitude.
  VadService? get vadService;

  Future<void> dispose();
}
