import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';

/// Owns the services needed to run one loaded ASR model
///
/// An [AsrRuntime] is created by [AsrRuntimeFactory] after the model assets and
/// vocabulary have been loaded successfully. UI code should use
/// [streamingService] for live transcription and call [dispose] when switching
/// away from this model
class AsrRuntime {
  const AsrRuntime({required this.pipeline, required this.streamingService});

  final AsrPipelineService pipeline;

  /// The streaming transcription API used by the home view model
  final StreamingTranscriptionService streamingService;

  Future<void> dispose() => pipeline.dispose();
}
