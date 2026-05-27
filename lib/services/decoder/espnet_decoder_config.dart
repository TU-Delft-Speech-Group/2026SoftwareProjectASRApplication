import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class EspnetDecoderConfig {
  const EspnetDecoderConfig({
    required this.modelAssetPath,
    required this.vocab,
    required this.decoderOutputSize,
    this.sessionOptions,
  });

  final String modelAssetPath;

  // Must match the CTC vocab size (last dim of the CTC logits tensor).
  final int vocab;

  // Decoder hidden size — sets the time=0 cache shape [1, 0, decoderOutputSize].
  final int decoderOutputSize;

  final OrtSessionOptions? sessionOptions;
}
