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

  // Production model. The client ships with this one only.
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

  // Dev-only. Same vocab layout (blank=0, unk=1, sos/eos=4999) as Gigaspeech,
  // so the vocab config is reused. Pubspec must declare the Librispeech assets
  // for this to load; the client build script strips them before packaging.
  static const englishLibrispeech = AsrModelConfig(
    encoderAsset:
        'assets/EnglishLibrispeechConformerFBank/full/default_encoder.onnx',
    ctcAsset: 'assets/EnglishLibrispeechConformerFBank/full/ctc.onnx',
    vocabAsset: 'assets/EnglishLibrispeechConformerFBank/vocab.txt',
    vocabConfig: VocabConfig.englishGigaspeech,
    blankId: 0,
    eosId: 4999,
    beamSize: 5,
  );

  /// Returns the config matching the given name. Falls back to Gigaspeech for
  /// anything unrecognised so a typo in --dart-define never picks Librispeech
  /// silently in a client build.
  static AsrModelConfig fromName(String name) {
    switch (name.toLowerCase()) {
      case 'librispeech':
      case 'english_librispeech':
        return englishLibrispeech;
      default:
        return englishGigaspeech;
    }
  }
}
