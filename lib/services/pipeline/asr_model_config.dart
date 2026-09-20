import 'package:asr_application/domain/models/model/model_metadata.dart';
import 'package:asr_application/services/token_decoder/vocab_config.dart';

/// Decoder ids and vocab settings shared by every exported ESPnet conformer
/// model. The asset paths needed to load a bundled model live on the asset
/// subtype [AsrAssetModelConfig]; installed models load via on-device file
/// paths and don't carry assets on the config at all.
class AsrModelConfig {
  const AsrModelConfig({
    required this.vocabConfig,
    required this.blankId,
    required this.eosId,
    required this.beamSize,
    this.decoderOutputSize = 0,
  });

  /// Builds a config from an installed model's manifest [metadata].
  ///
  /// [decoderOutputSize] is only a fallback: `EspnetDecoderService` reads the
  /// real value from the decoder ONNX model at load time.
  factory AsrModelConfig.fromMetadata(
    ModelMetadata metadata, {
    int beamSize = 1,
    int decoderOutputSize = 512,
  }) {
    return AsrModelConfig(
      vocabConfig: VocabConfig(
        unkId: metadata.unkId!,
        sosId: metadata.sosEosId!,
        eosId: metadata.sosEosId!,
        suppressedIds: metadata.suppressedIds,
        wordBoundaryMarker: metadata.wordBoundaryMarker,
      ),
      blankId: metadata.blankId!,
      eosId: metadata.sosEosId!,
      beamSize: beamSize,
      decoderOutputSize: decoderOutputSize,
    );
  }

  final VocabConfig vocabConfig;
  final int blankId;
  final int eosId;
  final int beamSize;
  // Transformer decoder hidden size; sets the empty-cache shape [1, 0, size].
  // Must match the model — verify against the ONNX session's input spec.
  final int decoderOutputSize;
}

/// Bundled-asset variant of [AsrModelConfig]. Carries the Flutter asset paths
/// the runtime factory loads from, so only this subtype can flow into the
/// asset-loading code path.
class AsrAssetModelConfig extends AsrModelConfig {
  const AsrAssetModelConfig({
    required this.encoderAsset,
    required this.ctcAsset,
    required this.vocabAsset,
    this.decoderAsset,
    required super.vocabConfig,
    required super.blankId,
    required super.eosId,
    required super.beamSize,
    super.decoderOutputSize,
  });

  final String encoderAsset;
  final String ctcAsset;
  final String vocabAsset;
  // null = CTC-only decoding; set to enable joint CTC+attention beam search.
  final String? decoderAsset;

  static const englishGigaspeech = AsrAssetModelConfig(
    encoderAsset:
        'assets/EnglishGigaspeechConformerFBank_M01/full/default_encoder.onnx',
    ctcAsset: 'assets/EnglishGigaspeechConformerFBank_M01/full/ctc.onnx',
    decoderAsset:
        'assets/EnglishGigaspeechConformerFBank_M01/full/xformer_decoder.onnx',
    vocabAsset: 'assets/EnglishGigaspeechConformerFBank_M01/vocab.txt',
    vocabConfig: VocabConfig.englishGigaspeech,
    blankId: 0,
    eosId: 4999,
    beamSize: 1,
    decoderOutputSize: 512,
  );
}
