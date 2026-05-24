import 'dart:io';

class ModelFiles {
  const ModelFiles({
    required this.ctcPath,
    required this.encoderPath,
    required this.decoderPath,
    required this.vocabPath,
  });

  final File ctcPath;
  final File encoderPath;
  final File decoderPath;
  final File vocabPath;
}
