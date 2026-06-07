import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:asr_application/services/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/decoder/decoder_service.dart';
import 'package:asr_application/services/decoder/espnet_decoder_service.dart';
import 'package:asr_application/services/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/bpe_token_id_to_text_service.dart';
import 'package:path/path.dart' as p;

// Builds an AsrRuntime out of the bundled .asrmodel for benchmark tests.
// Extracts the zip directly into a temp dir rather than going through
// ModelPackageService, which depends on path_provider.
class BenchmarkRuntime {
  BenchmarkRuntime._({required this.runtime, required Directory modelDir})
      : _modelDir = modelDir;

  final AsrRuntime runtime;
  final Directory _modelDir;

  Future<void> dispose() async {
    await runtime.dispose();
    if (await _modelDir.exists()) {
      await _modelDir.delete(recursive: true);
    }
  }

  static const _bundledPackage =
      'assets/EnglishGigaspeechConformerFBank_M01.asrmodel';

  // [packagePath], when set, loads an .asrmodel from a filesystem path
  // instead of the bundled asset (used for swapping models in benchmarks).
  static Future<BenchmarkRuntime> load({
    AsrModelConfig config = AsrModelConfig.englishGigaspeech,
    bool ctcOnly = false,
    String? packagePath,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('asr_bench_');

    final packageFile = File('${tempDir.path}/bundle.asrmodel');
    if (packagePath != null) {
      await File(packagePath).copy(packageFile.path);
    } else {
      final packageData = await rootBundle.load(_bundledPackage);
      await packageFile.writeAsBytes(packageData.buffer.asUint8List(
        packageData.offsetInBytes,
        packageData.lengthInBytes,
      ));
    }

    final inputStream = InputFileStream(packageFile.path);
    try {
      final archive = ZipDecoder().decodeBuffer(inputStream);
      await extractArchiveToDisk(archive, tempDir.path);
    } finally {
      await inputStream.close();
    }
    await packageFile.delete();

    final encoderPath = p.join(tempDir.path, 'encoder.onnx');
    final ctcPath = p.join(tempDir.path, 'ctc.onnx');
    final decoderPath = p.join(tempDir.path, 'decoder.onnx');
    final vocabPath = p.join(tempDir.path, 'vocab.txt');

    final hasDecoder = !ctcOnly && await File(decoderPath).exists();
    final decoder = hasDecoder
        ? EspnetDecoderService(
            config: EspnetDecoderConfig(
              modelFilePath: decoderPath,
              vocab: config.eosId + 1,
              decoderOutputSize: config.decoderOutputSize,
            ),
          )
        : null;

    final pipeline = AsrPipelineService(
      encoder: EspnetEncoderService(
        config: EspnetEncoderConfig(modelFilePath: encoderPath),
      ),
      ctc: EspnetCtcService(
        config: EspnetCtcConfig(modelFilePath: ctcPath),
      ),
      decoder: decoder,
    );

    try {
      await pipeline.initialize();
    } catch (_) {
      await pipeline.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      rethrow;
    }

    final vocabRaw = await File(vocabPath).readAsString();
    final vocab = vocabRaw.split('\n').where((l) => l.isNotEmpty).toList();
    final textService = BpeTokenIdToTextService.fromVocab(
      vocab,
      config: config.vocabConfig,
    );

    final runtime = AsrRuntime(
      pipeline: pipeline,
      streamingService: StreamingTranscriptionService(
        encode: pipeline.encode,
        decoder: DecoderService(
          blankId: config.blankId,
          eosId: config.eosId,
          beamSize: config.beamSize,
        ),
        textService: textService,
      ),
    );

    return BenchmarkRuntime._(runtime: runtime, modelDir: tempDir);
  }
}
