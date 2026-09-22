import 'dart:io';

class ModelFiles {
  const ModelFiles({
    required this.encoderPath,
    this.ctcPath,
    this.decoderPath,
    this.vocabPath,
    this.tokenizerPath,
  });

  final File encoderPath;

  /// Null for Whisper models (no CTC head).
  final File? ctcPath;

  /// Null when the model was packaged without a transformer decoder
  /// (CTC-only ESPnet models).
  final File? decoderPath;

  /// Sentencepiece vocab file. Null for Whisper models.
  final File? vocabPath;

  /// Whisper tokenizer.json file. Null for ESPnet models.
  final File? tokenizerPath;

  bool get hasCtc => ctcPath != null;
  bool get hasTokenizer => tokenizerPath != null;
}
