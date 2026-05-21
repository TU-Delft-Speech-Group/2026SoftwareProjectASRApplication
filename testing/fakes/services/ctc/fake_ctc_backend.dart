import 'dart:typed_data';

import 'package:asr_application/services/shared/onnx/onnx.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class FakeCtcBackend implements OnnxInferenceBackendContract {
  FakeCtcBackend({required this.outputs, this.runError});

  final Map<String, OnnxTensorContract> outputs;
  final Object? runError;
  final session = FakeCtcSession();
  final createdTensors = <FakeCtcTensor>[];
  String? createdAssetPath;
  int createSessionCallCount = 0;

  @override
  Future<FakeCtcSession> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  }) async {
    createSessionCallCount++;
    createdAssetPath = assetPath;
    session.outputs = outputs;
    session.runError = runError;
    return session;
  }

  @override
  Future<FakeCtcTensor> createTensor(dynamic data, List<int> shape) async {
    final tensor = FakeCtcTensor(data, shape);
    createdTensors.add(tensor);
    return tensor;
  }
}

class FakeCtcSession implements OnnxInferenceSessionContract {
  Map<String, OnnxTensorContract> inputs = {};
  Map<String, OnnxTensorContract> outputs = {};
  Object? runError;
  bool closed = false;
  int runCallCount = 0;

  @override
  Future<Map<String, OnnxTensorContract>> run(
    Map<String, OnnxTensorContract> inputs,
  ) async {
    runCallCount++;
    this.inputs = inputs;
    final error = runError;
    if (error != null) {
      throw error;
    }
    return outputs;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class FakeCtcTensor implements OnnxTensorContract {
  FakeCtcTensor(this.data, this.shape);

  final dynamic data;
  bool disposeCalled = false;

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
    throw StateError('Fake CTC tensor does not contain float data.');
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
    throw StateError('Fake CTC tensor data is not list-like.');
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
  }
}
