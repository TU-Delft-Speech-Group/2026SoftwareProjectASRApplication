import 'package:flutter/foundation.dart';
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
    debugPrint('WHISPER: createRuntime called');
    debugPrint('WHISPER: encoder=${files.encoderPath.path}');
    debugPrint('WHISPER: decoder=${files.decoderPath?.path}');
    debugPrint('WHISPER: tokenizer=${files.tokenizerPath?.path}');

    try {
      final pipeline = WhisperAsrPipeline(
        encoderPath: files.encoderPath.path,
        decoderPath: files.decoderPath!.path,
      );

      debugPrint('WHISPER: calling pipeline.initialize()...');
      await pipeline.initialize();
      debugPrint('WHISPER: pipeline initialized OK');

      debugPrint('WHISPER: loading tokenizer...');
      final tokenizer = await WhisperTokenizer.load(
        files.tokenizerPath!.path,
      );
      debugPrint('WHISPER: tokenizer loaded OK');

      final transcription = WhisperTranscriptionService(
        pipeline: pipeline,
        tokenizer: tokenizer,
        language: metadata.language ?? 'en',
      );

      debugPrint('WHISPER: runtime ready!');
      return WhisperAsrRuntime(
        pipeline: pipeline,
        transcription: transcription,
      );
    } catch (e, st) {
      debugPrint('WHISPER ERROR: $e');
      debugPrint('WHISPER STACK: $st');
      rethrow;
    }
  }

}
