import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Configuration for loading an ESPnet CTC ONNX model.
class EspnetCtcConfig {
  EspnetCtcConfig({
    this.modelAssetPath,
    this.modelFilePath,
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
  final OrtSessionOptions? sessionOptions;
}
