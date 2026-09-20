import 'package:asr_application/services/audio/vad_service.dart';
import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_transcription_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';

/// Runtime instance for a loaded Whisper model.
class WhisperAsrRuntime implements AsrRuntime {
  WhisperAsrRuntime({
    required this.pipeline,
    required WhisperTranscriptionService transcription,
    this.vadService,
  }) : _transcription = transcription;

  final WhisperAsrPipeline pipeline;
  final WhisperTranscriptionService _transcription;

  @override
  AsrTranscriptionService get transcriptionService => _transcription;

  @override
  final VadService? vadService;

  @override
  Future<void> dispose() async {
    await pipeline.dispose();
  }
}
