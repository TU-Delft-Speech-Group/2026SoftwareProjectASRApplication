import 'package:asr_application/services/audio/vad_service.dart';
import 'package:asr_application/services/engines/espnet/pipeline/espnet_asr_pipeline.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';

/// Runtime for one loaded ESPnet ASR model.
final class EspnetAsrRuntime implements AsrRuntime {
  const EspnetAsrRuntime({
    required this.pipeline,
    required this.transcriptionService,
    this.vadService,
  });

  final EspnetAsrPipeline pipeline;

  @override
  final AsrTranscriptionService transcriptionService;

  @override
  final VadService? vadService;

  @override
  Future<void> dispose() async {
    await Future.wait([
      pipeline.dispose(),
      if (vadService != null) vadService!.dispose(),
    ]);
  }
}
