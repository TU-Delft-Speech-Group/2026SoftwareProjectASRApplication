import 'dart:convert';
import 'dart:developer' as dev;

import 'package:asr_application/domain/models/model/model_files.dart';
import 'package:asr_application/services/audio/silero_vad_service.dart';
import 'package:asr_application/services/audio/vad_service.dart';
import 'package:asr_application/services/engines/espnet/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/espnet_decoder_service.dart';
import 'package:asr_application/services/engines/espnet/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/pipeline/asr_initialization_exception.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/services/token_decoder/bpe_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'package:flutter/foundation.dart';

// Select decoding mode at build time:
//   flutter run --dart-define=ASR_DECODER=joint  (default, CTC + attention)
//   flutter run --dart-define=ASR_DECODER=ctc    (CTC-only, faster)
//
// Joint mode is only active when the selected model has a decoder asset.
const _decoderMode = String.fromEnvironment(
  'ASR_DECODER',
  defaultValue: 'joint',
);

/// Builds a complete ASR runtime from either bundled assets or files on disk.
///
/// Every consumer (the app loading a bundled or installed model, the accuracy
/// benchmark loading an extracted .asrmodel) goes through this factory so the
/// encoder + CTC + optional decoder + vocabulary + streaming wiring is
/// identical regardless of where the model came from.
class AsrRuntimeFactory {
  const AsrRuntimeFactory({this.vadBackend});

  // Injected ONNX backend for the VAD service; null uses the real backend.
  // Provide a fake in tests to exercise tryCreateVadService without assets.
  final OnnxInferenceBackendContract? vadBackend;

  Future<AsrRuntime> create(AsrAssetModelConfig model) async {
    final decoder = _createAssetDecoder(model);
    final pipeline = AsrPipelineService(
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
      name: 'AsrRuntimeFactory',
    );

    await _initializePipeline(pipeline);

    final TokenIdToTextService textService;
    try {
      textService = await BpeTokenIdToTextService.load(
        model.vocabAsset,
        config: model.vocabConfig,
      );
      dev.log('vocabulary loaded: ${model.vocabAsset}', name: 'AsrRuntimeFactory');
    } catch (error, stackTrace) {
      await pipeline.dispose();
      throw AsrInitializationException(
        stage: 'vocabulary loading',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final vadService = await tryCreateVadService();
    return _assemble(
      pipeline: pipeline,
      config: model,
      textService: textService,
      vadService: vadService,
    );
  }

  /// Builds the same runtime from model files on disk. Used by the app for
  /// installed models and by the accuracy benchmark for extracted packages.
  ///
  /// [joint] overrides the ASR_DECODER dart-define when set; a decoder is only
  /// used when the mode is joint and [ModelFiles.decoderPath] is present.
  Future<AsrRuntime> createFromFiles(
    ModelFiles files,
    AsrModelConfig config, {
    bool? joint,
  }) async {
    final useJoint =
        (joint ?? _decoderMode == 'joint') && files.decoderPath != null;
    final decoder = useJoint
        ? EspnetDecoderService(
            config: EspnetDecoderConfig(
              modelFilePath: files.decoderPath!.path,
              vocab: config.eosId + 1,
              decoderOutputSize: config.decoderOutputSize,
            ),
          )
        : null;
    final pipeline = AsrPipelineService(
      encoder: EspnetEncoderService(
        config: EspnetEncoderConfig(modelFilePath: files.encoderPath.path),
      ),
      ctc: EspnetCtcService(
        config: EspnetCtcConfig(modelFilePath: files.ctcPath.path),
      ),
      decoder: decoder,
    );
    dev.log(
      'loading model: encoder=${files.encoderPath.path}, '
      'ctc=${files.ctcPath.path}, '
      'decoder=${decoder != null ? files.decoderPath!.path : 'none (CTC-only)'}',
      name: 'AsrRuntimeFactory',
    );

    await _initializePipeline(pipeline);

    final TokenIdToTextService textService;
    try {
      final raw = await files.vocabPath.readAsString();
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
        'vocabulary loaded: ${files.vocabPath.path}',
        name: 'AsrRuntimeFactory',
      );
    } catch (error, stackTrace) {
      await pipeline.dispose();
      throw AsrInitializationException(
        stage: 'vocabulary loading',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final vadService = await tryCreateVadService();
    return _assemble(
      pipeline: pipeline,
      config: config,
      textService: textService,
      vadService: vadService,
    );
  }

  Future<void> _initializePipeline(AsrPipelineService pipeline) async {
    try {
      await pipeline.initialize();
      dev.log('pipeline initialized', name: 'AsrRuntimeFactory');
    } catch (error, stackTrace) {
      await pipeline.dispose();
      throw AsrInitializationException(
        stage: 'model loading',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<AsrRuntime> _assemble({
    required AsrPipelineService pipeline,
    required AsrModelConfig config,
    required TokenIdToTextService textService,
    VadService? vadService,
  }) async {
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
      vadService: vadService,
    );
  }

  @visibleForTesting
  Future<VadService?> tryCreateVadService() async {
    try {
      final svc = SileroVadService(backend: vadBackend);
      await svc.initialize();
      dev.log('SileroVadService initialized', name: 'AsrRuntimeFactory');
      return svc;
    } catch (error) {
      dev.log(
        'SileroVadService unavailable, falling back to amplitude threshold: $error',
        name: 'AsrRuntimeFactory',
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
}
