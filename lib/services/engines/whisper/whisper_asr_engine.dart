import 'package:asr_application/domain/models/model/model_files.dart';
import 'package:asr_application/domain/models/model/model_metadata.dart';
import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_asr_runtime.dart';
import 'package:asr_application/services/engines/whisper/whisper_tokenizer.dart';
import 'package:asr_application/services/engines/whisper/whisper_transcription_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';

/// Factory that creates a [WhisperAsrRuntime] from installed model files.
class WhisperAsrEngine {
  const WhisperAsrEngine();

  Future<AsrRuntime> createRuntime(
    ModelFiles files,
    ModelMetadata metadata,
  ) async {
    assert(files.decoderPath != null, 'Whisper requires a decoder ONNX file.');
    assert(files.tokenizerPath != null, 'Whisper requires a tokenizer.json.');

    final pipeline = WhisperAsrPipeline(
      encoderPath: files.encoderPath.path,
      decoderPath: files.decoderPath!.path,
    );
    await pipeline.initialize();

    final tokenizer = await WhisperTokenizer.load(
      files.tokenizerPath!.path,
    );

    final transcription = WhisperTranscriptionService(
      pipeline: pipeline,
      tokenizer: tokenizer,
      language: metadata.language ?? 'en',
    );

    return WhisperAsrRuntime(
      pipeline: pipeline,
      transcription: transcription,
    );
  }
}
