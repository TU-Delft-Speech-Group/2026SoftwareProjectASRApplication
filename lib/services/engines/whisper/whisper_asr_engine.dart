import 'package:flutter/foundation.dart';
import 'package:asr_application/domain/models/model/model_files.dart';
import 'package:asr_application/domain/models/model/model_metadata.dart';
import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_mel_service.dart';
import 'package:asr_application/services/engines/whisper/whisper_asr_runtime.dart';
import 'package:asr_application/services/engines/whisper/whisper_tokenizer.dart';
import 'package:asr_application/services/engines/whisper/whisper_transcription_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';

class WhisperAsrEngine {
  const WhisperAsrEngine();

  Future<AsrRuntime> createRuntime(
    ModelFiles files,
    ModelMetadata metadata,
  ) async {
    debugPrint('WHISPER: createRuntime called');

    try {
      final pipeline = WhisperAsrPipeline(
        encoderPath: files.encoderPath.path,
        decoderPath: files.decoderPath!.path,
      );

      debugPrint('WHISPER: initializing pipeline...');
      await pipeline.initialize();
      debugPrint('WHISPER: pipeline initialized OK');

      final melFilterPath = '${files.encoderPath.parent.path}/mel_filters.json';
      debugPrint('WHISPER: loading mel filterbank...');
      final melService = await WhisperMelService.fromFilterbankFile(melFilterPath);
      debugPrint('WHISPER: mel service ready');

      debugPrint('WHISPER: loading tokenizer...');
      final tokenizer = await WhisperTokenizer.load(files.tokenizerPath!.path);
      debugPrint('WHISPER: tokenizer loaded OK');

      final transcription = WhisperTranscriptionService(
        pipeline: pipeline,
        tokenizer: tokenizer,
        language: metadata.language ?? 'en',
        melService: melService,
      );

      debugPrint('WHISPER: runtime ready!');
      return WhisperAsrRuntime(
        pipeline: pipeline,
        transcription: transcription,
      );
    } catch (e) {
      debugPrint('WHISPER ERROR: $e');
      rethrow;
    }
  }
}
