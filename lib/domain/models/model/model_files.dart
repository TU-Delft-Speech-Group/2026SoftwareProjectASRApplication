import 'dart:io';

class ModelFiles {
  const ModelFiles({
    required this.ctcPath,
    required this.encoderPath,
    this.decoderPath,
    required this.vocabPath,
  });

  final File ctcPath;
  final File encoderPath;

  /// Null when the model was packaged without a transformer decoder
  /// (CTC-only models). The pipeline falls back to CTC-greedy decoding.
  final File? decoderPath;
  final File vocabPath;
}
