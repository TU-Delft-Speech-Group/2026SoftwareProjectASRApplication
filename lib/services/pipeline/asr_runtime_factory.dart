import 'package:asr_application/services/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/decoder/decoder_service.dart';
import 'package:asr_application/services/decoder/espnet_decoder_service.dart';
import 'package:asr_application/services/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/pipeline/asr_initialization_exception.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/bpe_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'dart:developer' as dev;

// Select decoding mode at build time:
//   flutter run --dart-define=ASR_DECODER=joint  (default, CTC + attention)
//   flutter run --dart-define=ASR_DECODER=ctc    (CTC-only, faster)
//
// Joint mode is only active when the selected model has a decoder asset.
const _decoderMode = String.fromEnvironment(
  'ASR_DECODER',
  defaultValue: 'joint',
);

/// Builds a complete ASR runtime for a bundled-asset model configuration
///
/// Takes an [AsrAssetModelConfig] because it loads the ONNX encoder, ONNX CTC
/// head, vocabulary, and decoder from Flutter asset paths. Installed (file-
/// based) models bypass this factory and load via a custom loader.
class AsrRuntimeFactory {
  const AsrRuntimeFactory();

  Future<AsrRuntime> create(AsrAssetModelConfig model) async {
    final decoder = _createDecoder(model);
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

    return AsrRuntime(
      pipeline: pipeline,
      streamingService: StreamingTranscriptionService(
        encode: pipeline.encode,
        decoder: DecoderService(
          blankId: model.blankId,
          eosId: model.eosId,
          beamSize: model.beamSize,
        ),
        textService: textService,
      ),
    );
  }

  EspnetDecoderService? _createDecoder(AsrAssetModelConfig model) {
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
