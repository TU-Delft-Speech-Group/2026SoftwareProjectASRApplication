import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Configuration for loading an ESPnet CTC ONNX model.
class EspnetCtcConfig {
  const EspnetCtcConfig({required this.modelAssetPath, this.sessionOptions});

  final String modelAssetPath;
  final OrtSessionOptions? sessionOptions;
}
