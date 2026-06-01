import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class EspnetDecoderConfig {
  EspnetDecoderConfig({
    this.modelAssetPath,
    this.modelFilePath,
    required this.vocab,
    required this.decoderOutputSize,
    this.sessionOptions,
  }) {
    if (modelAssetPath == null && modelFilePath == null) {
      throw ArgumentError(
        'Either modelAssetPath or modelFilePath must be provided',
      );
    }
  }

  final String? modelAssetPath;
  final String? modelFilePath;

  // Must match the CTC vocab size (last dim of the CTC logits tensor).
  final int vocab;

  // Decoder hidden size — sets the time=0 cache shape [1, 0, decoderOutputSize].
  final int decoderOutputSize;

  final OrtSessionOptions? sessionOptions;
}
