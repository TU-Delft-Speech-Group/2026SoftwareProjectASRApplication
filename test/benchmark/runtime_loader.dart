import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/services/engines/espnet/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/espnet_decoder_service.dart';
import 'package:asr_application/services/engines/espnet/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/bpe_token_id_to_text_service.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

// Builds an AsrRuntime for benchmark tests. Resolves a model source in
// priority order:
//   1. [packagePath] when supplied, extracted from a filesystem .asrmodel.
//   2. The bundled .asrmodel asset, extracted from rootBundle.
//   3. A model already installed by the production install pipeline at
//      <documents>/models/<name>/, used in place.
//
// Each source produces the same on-disk layout (encoder.onnx, ctc.onnx,
// optional decoder.onnx, vocab.txt) which the runtime is built against.
class BenchmarkRuntime {
  BenchmarkRuntime._({required this.runtime, Directory? temporaryDir})
    : _temporaryDir = temporaryDir;

  final AsrRuntime runtime;
  // Set when load() owns a model directory it extracted and should delete on
  // dispose. Null when the runtime is built against a directory managed by
  // the production install pipeline.
  final Directory? _temporaryDir;

  Future<void> dispose() async {
    await runtime.dispose();
    final dir = _temporaryDir;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static const _bundledPackage =
      'assets/EnglishGigaspeechConformerFBank_M01.asrmodel';

  static Future<BenchmarkRuntime> load({
    AsrModelConfig config = AsrAssetModelConfig.englishGigaspeech,
    bool ctcOnly = false,
    String? packagePath,
  }) async {
    if (packagePath != null) {
      final tempDir = await _extractFromFile(File(packagePath));
      return _buildFromTemp(tempDir, config: config, ctcOnly: ctcOnly);
    }

    try {
      final data = await rootBundle.load(_bundledPackage);
      final tempDir = await _extractFromBytes(data);
      return _buildFromTemp(tempDir, config: config, ctcOnly: ctcOnly);
    } on FlutterError {
      // No bundled asset; fall through to installed-model path.
    }

    final installedDir = await _firstInstalledModelDir();
    if (installedDir == null) {
      throw StateError(
        'No model available to the benchmark. Either bundle an .asrmodel '
        'under $_bundledPackage, pass packagePath to load() '
        '(or set ASRMODEL_PATH on the integration test), or install a '
        'model through the app so it lands under <documents>/models/.',
      );
    }
    final runtime = await _buildRuntimeFromDir(
      installedDir.path,
      config: config,
      ctcOnly: ctcOnly,
    );
    return BenchmarkRuntime._(runtime: runtime);
  }

  static Future<BenchmarkRuntime> _buildFromTemp(
    Directory tempDir, {
    required AsrModelConfig config,
    required bool ctcOnly,
  }) async {
    try {
      final runtime = await _buildRuntimeFromDir(
        tempDir.path,
        config: config,
        ctcOnly: ctcOnly,
      );
      return BenchmarkRuntime._(runtime: runtime, temporaryDir: tempDir);
    } catch (_) {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  static Future<Directory> _extractFromFile(File source) async {
    final tempDir = await Directory.systemTemp.createTemp('asr_bench_');
    final inputStream = InputFileStream(source.path);
    try {
      final archive = ZipDecoder().decodeBuffer(inputStream);
      await extractArchiveToDisk(archive, tempDir.path);
    } finally {
      await inputStream.close();
    }
    return tempDir;
  }

  static Future<Directory> _extractFromBytes(ByteData data) async {
    final tempDir = await Directory.systemTemp.createTemp('asr_bench_');
    final packageFile = File('${tempDir.path}/bundle.asrmodel');
    await packageFile.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      final inputStream = InputFileStream(packageFile.path);
      try {
        final archive = ZipDecoder().decodeBuffer(inputStream);
        await extractArchiveToDisk(archive, tempDir.path);
      } finally {
        await inputStream.close();
      }
    } finally {
      if (await packageFile.exists()) await packageFile.delete();
    }
    return tempDir;
  }

  // Locates the first model installed by the production install pipeline. The
  // benchmark uses this when no bundled asset and no explicit packagePath are
  // available, so the test runs against whatever the user installed via the
  // settings page.
  static Future<Directory?> _firstInstalledModelDir() async {
    const storage = LocalModelStorageConfig();
    final localService = LocalModelService(config: storage);
    final List<String> names;
    try {
      names = await localService.getAvailableModels();
    } catch (_) {
      return null;
    }
    if (names.isEmpty) return null;
    return localService.getModelDirectory(names.first);
  }

  static Future<AsrRuntime> _buildRuntimeFromDir(
    String dirPath, {
    required AsrModelConfig config,
    required bool ctcOnly,
  }) async {
    final encoderPath = p.join(dirPath, 'encoder.onnx');
    final ctcPath = p.join(dirPath, 'ctc.onnx');
    final decoderPath = p.join(dirPath, 'decoder.onnx');
    final vocabPath = p.join(dirPath, 'vocab.txt');

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
      ctc: EspnetCtcService(config: EspnetCtcConfig(modelFilePath: ctcPath)),
      decoder: decoder,
    );

    try {
      await pipeline.initialize();
    } catch (_) {
      await pipeline.dispose();
      rethrow;
    }

    final vocabRaw = await File(vocabPath).readAsString();
    final vocab = vocabRaw.split('\n').where((l) => l.isNotEmpty).toList();
    final textService = BpeTokenIdToTextService.fromVocab(
      vocab,
      config: config.vocabConfig,
    );

    return AsrRuntime(
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
  }
}
