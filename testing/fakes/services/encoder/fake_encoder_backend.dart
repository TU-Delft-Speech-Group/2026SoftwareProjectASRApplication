import 'dart:typed_data';

import 'package:asr_application/services/shared/onnx/onnx.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class FakeEncoderBackend implements OnnxInferenceBackendContract {
  FakeEncoderBackend({required this.outputs});

  final Map<String, OnnxTensorContract> outputs;
  final session = FakeEncoderSession();
  String? createdAssetPath;

  @override
  Future<FakeEncoderSession> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  }) async {
    createdAssetPath = assetPath;
    session.outputs = outputs;
    return session;
  }

  @override
  Future<FakeEncoderTensor> createTensor(dynamic data, List<int> shape) async {
    return FakeEncoderTensor(data, shape);
  }
}

class FakeEncoderSession implements OnnxInferenceSessionContract {
  Map<String, OnnxTensorContract> inputs = {};
  Map<String, OnnxTensorContract> outputs = {};
  bool closed = false;

  @override
  Future<Map<String, OnnxTensorContract>> run(
    Map<String, OnnxTensorContract> inputs,
  ) async {
    this.inputs = inputs;
    return outputs;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class FakeEncoderTensor implements OnnxTensorContract {
  FakeEncoderTensor(this.data, this.shape);

  final dynamic data;

  @override
  final List<int> shape;

  @override
  Future<Float32List> asFloat32List() async {
    if (data is Float32List) {
      return data as Float32List;
    }
    if (data is List<num>) {
      return Float32List.fromList(
        (data as List<num>).map((value) => value.toDouble()).toList(),
      );
    }
    throw StateError('Fake tensor does not contain float data.');
  }

  @override
  Future<List<dynamic>> asList() async {
    if (data is List) {
      return List<dynamic>.from(data as List);
    }
    if (data is Int64List) {
      return List<dynamic>.from(data as Int64List);
    }
    if (data is Float32List) {
      return List<dynamic>.from(data as Float32List);
    }
    throw StateError('Fake tensor data is not list-like.');
  }

  @override
  Future<void> dispose() async {}
}
