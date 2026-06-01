import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

abstract class OnnxInferenceBackendContract {
  Future<OnnxInferenceSessionContract> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  });

  Future<OnnxInferenceSessionContract> createSessionFromFile(
    String filePath, {
    OrtSessionOptions? options,
  });

  Future<OnnxTensorContract> createTensor(dynamic data, List<int> shape);
}

abstract class OnnxInferenceSessionContract {
  Future<Map<String, OnnxTensorContract>> run(
    Map<String, OnnxTensorContract> inputs,
  );

  Future<void> close();
}

abstract class OnnxTensorContract {
  List<int> get shape;

  Future<Float32List> asFloat32List();

  Future<List<dynamic>> asList();

  Future<void> dispose();
}
