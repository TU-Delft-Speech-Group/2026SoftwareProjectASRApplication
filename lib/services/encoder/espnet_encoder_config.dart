import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Configuration for loading an ESPnet encoder ONNX model
class EspnetEncoderConfig {
  const EspnetEncoderConfig({
    required this.modelAssetPath,
    this.sessionOptions,
  });

  final String modelAssetPath;
  final OrtSessionOptions? sessionOptions;
}
