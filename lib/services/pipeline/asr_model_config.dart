import 'package:asr_application/services/token_decoder/vocab_config.dart';

/// Bundles every asset path and decoder id that varies between exported
/// ESPnet conformer models. Selecting a different config swaps the model the
/// app loads without touching any pipeline wiring.
class AsrModelConfig {
  const AsrModelConfig({
    required this.encoderAsset,
    required this.ctcAsset,
    required this.vocabAsset,
    required this.vocabConfig,
    required this.blankId,
    required this.eosId,
    required this.beamSize,
  });

  final String encoderAsset;
  final String ctcAsset;
  final String vocabAsset;
  final VocabConfig vocabConfig;
  final int blankId;
  final int eosId;
  final int beamSize;

  static const englishGigaspeech = AsrModelConfig(
    encoderAsset:
        'assets/EnglishGigaspeechConformerFBank_M01/full/default_encoder.onnx',
    ctcAsset: 'assets/EnglishGigaspeechConformerFBank_M01/full/ctc.onnx',
    vocabAsset: 'assets/EnglishGigaspeechConformerFBank_M01/vocab.txt',
    vocabConfig: VocabConfig.englishGigaspeech,
    blankId: 0,
    eosId: 4999,
    beamSize: 5,
  );
}
