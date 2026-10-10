import 'dart:developer' as dev;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:asr_application/domain/models/model/model_files.dart';
import 'package:asr_application/domain/models/model/model_metadata.dart';
import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_asr_runtime.dart';
import 'package:asr_application/services/engines/whisper/whisper_mel_service.dart';
import 'package:asr_application/services/engines/whisper/whisper_tokenizer.dart';
import 'package:asr_application/services/engines/whisper/whisper_transcription_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';

/// Builds a [WhisperAsrRuntime] from an installed model folder.
///
/// Packages with cross_kv.onnx next to the encoder use the KV-cache decoder
/// (decoder.onnx is then the one-token decoder_step); all others use the
/// full-sequence decoder.
class WhisperAsrEngine {
  const WhisperAsrEngine();

  static const _log = 'WhisperEngine';

  Future<AsrRuntime> createRuntime(
    ModelFiles files,
    ModelMetadata metadata,
  ) async {
    final dir = files.encoderPath.parent.path;
    final decoder = files.decoderPath;
    final tokenizerFile = files.tokenizerPath;
    if (decoder == null || tokenizerFile == null) {
      throw StateError(
        'Whisper model in $dir is incomplete: decoder.onnx and tokenizer.json are required.',
      );
    }

    final crossKv = File(p.join(dir, 'cross_kv.onnx'));
    final WhisperAsrPipeline pipeline = crossKv.existsSync()
        ? WhisperKvAsrPipeline(
            encoderPath: files.encoderPath.path,
            decoderStepPath: decoder.path,
            crossKvPath: crossKv.path,
          )
        : WhisperAsrPipeline(
            encoderPath: files.encoderPath.path,
            decoderPath: decoder.path,
          );
    dev.log('Loading ${pipeline is WhisperKvAsrPipeline ? "KV-cache" : "full-sequence"} '
        'pipeline from $dir', name: _log);

    try {
      await pipeline.initialize();
      final melService =
          await WhisperMelService.fromFilterbankFile(p.join(dir, 'mel_filters.json'));
      final tokenizer = await WhisperTokenizer.load(tokenizerFile.path);

      final transcription = WhisperTranscriptionService(
        pipeline: pipeline,
        tokenizer: tokenizer,
        language: metadata.language ?? 'en',
        melService: melService,
      );
      dev.log('Runtime ready (language ${metadata.language ?? "en"})', name: _log);
      return WhisperAsrRuntime(pipeline: pipeline, transcription: transcription);
    } catch (e, st) {
      dev.log('Failed to create runtime', error: e, stackTrace: st, name: _log);
      await pipeline.dispose(); // do not leak ONNX sessions on a failed load
      rethrow;
    }
  }
}
