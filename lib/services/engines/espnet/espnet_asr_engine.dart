import 'dart:convert';
import 'dart:developer' as dev;

import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/domain/models/model/model_files.dart';
import 'package:asr_application/domain/models/model/model_type.dart';
import 'package:asr_application/services/audio/silero_vad_service.dart';
import 'package:asr_application/services/audio/vad_service.dart';
import 'package:asr_application/services/engines/asr_engine.dart';
import 'package:asr_application/services/engines/espnet/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/espnet_decoder_service.dart';
import 'package:asr_application/services/engines/espnet/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/engines/espnet/pipeline/espnet_asr_pipeline.dart';
import 'package:asr_application/services/engines/espnet/pipeline/espnet_asr_runtime.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/pipeline/asr_initialization_exception.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/services/token_decoder/bpe_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'package:flutter/foundation.dart';

// Select decoding mode at build time:
//   flutter run --dart-define=ASR_DECODER=joint  (default, CTC + attention)
//   flutter run --dart-define=ASR_DECODER=ctc    (CTC-only, faster)
//
// Joint mode is only active when the selected model has a decoder.
const _decoderMode = String.fromEnvironment(
  'ASR_DECODER',
  defaultValue: 'joint',
);

/// Builds complete ESPnet runtimes from bundled assets or installed model files.
class EspnetAsrEngine implements AsrEngine {
  const EspnetAsrEngine({this.vadBackend});

  // Injected ONNX backend for the VAD service; null uses the real backend.
  // Provide a fake in tests to exercise tryCreateVadService without assets.
  final OnnxInferenceBackendContract? vadBackend;

  @override
  String get modelType => ModelType.espnet;

  @override
  Future<AsrRuntime> createRuntime(Model model) {
    // Derive the config from the package manifest when it carries vocab
    // metadata (format version 2+); otherwise fall back to the gigaspeech
    // defaults, which suit legacy (version 1) bundles like the shipped model.
    final config = model.metadata != null
        ? AsrModelConfig.fromMetadata(model.metadata!)
        : AsrAssetModelConfig.englishGigaspeech;
    return createFromModelFiles(model.files, config);
  }

  Future<AsrRuntime> createFromAssetConfig(AsrAssetModelConfig model) async {
    final decoder = _createAssetDecoder(model);
    final pipeline = EspnetAsrPipeline(
      encoder: EspnetEncoderService(
        config: EspnetEncoderConfig(modelAssetPath: model.encoderAsset),
      ),
      ctc: EspnetCtcService(
        config: EspnetCtcConfig(modelAssetPath: model.ctcAsset),
      ),
      decoder: decoder,
    );
    dev.log(
      'loading model: encoder=${model.encoderAsset}, ctc=${model.ctcAsset}, '
      'decoder=${decoder != null ? model.decoderAsset : 'none (CTC-only)'}',
      name: 'EspnetAsrEngine',
    );

    await _initializePipeline(pipeline);

    final TokenIdToTextService textService;
    try {
      textService = await BpeTokenIdToTextService.load(
        model.vocabAsset,
        config: model.vocabConfig,
      );
      dev.log(
        'vocabulary loaded: ${model.vocabAsset}',
        name: 'EspnetAsrEngine',
      );
    } catch (error, stackTrace) {
      await pipeline.dispose();
      throw AsrInitializationException(
        stage: 'vocabulary loading',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return _createRuntime(
      pipeline: pipeline,
      config: model,
      textService: textService,
    );
  }

  Future<AsrRuntime> createFromModelFiles(
    ModelFiles modelFiles,
    AsrModelConfig config, {
    bool? joint,
  }) async {
    final decoder = _createFileDecoder(modelFiles, config, joint: joint);
    dev.log(
      'loading model: encoder=${modelFiles.encoderPath.path}, '
      'ctc=${modelFiles.ctcPath.path}, '
      'decoder=${decoder != null ? modelFiles.decoderPath!.path : 'none (CTC-only)'}',
      name: 'EspnetAsrEngine',
    );

    final pipeline = EspnetAsrPipeline(
      encoder: EspnetEncoderService(
        config: EspnetEncoderConfig(modelFilePath: modelFiles.encoderPath.path),
      ),
      ctc: EspnetCtcService(
        config: EspnetCtcConfig(modelFilePath: modelFiles.ctcPath.path),
      ),
      decoder: decoder,
    );

    await _initializePipeline(pipeline);

    final TokenIdToTextService textService;
    try {
      final raw = await modelFiles.vocabPath.readAsString();
      // LineSplitter handles CRLF: packages produced on Windows otherwise
      // leave a trailing \r on every token, which garbles word joining.
      final vocab = const LineSplitter()
          .convert(raw)
          .where((line) => line.isNotEmpty)
          .toList();
      textService = BpeTokenIdToTextService.fromVocab(
        vocab,
        config: config.vocabConfig,
      );
      dev.log(
        'vocabulary loaded: ${modelFiles.vocabPath.path}',
        name: 'EspnetAsrEngine',
      );
    } catch (error, stackTrace) {
      await pipeline.dispose();
      throw AsrInitializationException(
        stage: 'vocabulary loading',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return _createRuntime(
      pipeline: pipeline,
      config: config,
      textService: textService,
    );
  }

  Future<void> _initializePipeline(EspnetAsrPipeline pipeline) async {
    try {
      await pipeline.initialize();
      dev.log('pipeline initialized', name: 'EspnetAsrEngine');
    } catch (error, stackTrace) {
      await pipeline.dispose();
      throw AsrInitializationException(
        stage: 'model loading',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<AsrRuntime> _createRuntime({
    required EspnetAsrPipeline pipeline,
    required AsrModelConfig config,
    required TokenIdToTextService textService,
  }) async {
    final vadService = await tryCreateVadService();

    return EspnetAsrRuntime(
      pipeline: pipeline,
      transcriptionService: StreamingTranscriptionService(
        encode: pipeline.encode,
        decoder: DecoderService(
          blankId: config.blankId,
          eosId: config.eosId,
          beamSize: config.beamSize,
        ),
        textService: textService,
      ),
      vadService: vadService,
    );
  }

  @visibleForTesting
  Future<VadService?> tryCreateVadService() async {
    try {
      final svc = SileroVadService(backend: vadBackend);
      await svc.initialize();
      dev.log('SileroVadService initialized', name: 'EspnetAsrEngine');
      return svc;
    } catch (error) {
      dev.log(
        'SileroVadService unavailable, falling back to amplitude threshold: $error',
        name: 'EspnetAsrEngine',
        level: 800,
      );
      return null;
    }
  }

  EspnetDecoderService? _createAssetDecoder(AsrAssetModelConfig model) {
    if (_decoderMode != 'joint' || model.decoderAsset == null) {
      return null;
    }

    return EspnetDecoderService(
      config: EspnetDecoderConfig(
        modelAssetPath: model.decoderAsset!,
        vocab: model.eosId + 1,
        decoderOutputSize: model.decoderOutputSize,
      ),
    );
  }

  EspnetDecoderService? _createFileDecoder(
    ModelFiles modelFiles,
    AsrModelConfig config, {
    bool? joint,
  }) {
    final useJoint = (joint ?? _decoderMode == 'joint');
    if (!useJoint || modelFiles.decoderPath == null) {
      return null;
    }

    return EspnetDecoderService(
      config: EspnetDecoderConfig(
        modelFilePath: modelFiles.decoderPath!.path,
        vocab: config.eosId + 1,
        decoderOutputSize: config.decoderOutputSize,
      ),
    );
  }
}
