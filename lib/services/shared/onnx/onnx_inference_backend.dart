import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'onnx_inference_contracts.dart';
import 'onnx_inference_session.dart';
import 'onnx_tensor.dart';

/// Shared ONNX Runtime adapter used by ASR services.
///
/// It owns the conversion from Dart values to `OrtValue`s and creates runtime
/// sessions from model assets.
class OnnxInferenceBackend implements OnnxInferenceBackendContract {
  OnnxInferenceBackend({OnnxRuntime? runtime})
    : _runtime = runtime ?? OnnxRuntime();

  final OnnxRuntime _runtime;

  @override
  Future<OnnxInferenceSession> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  }) async {
    final session = await _runtime.createSessionFromAsset(
      assetPath,
      options: options,
    );
    return OnnxInferenceSession(session);
  }

  @override
  Future<OnnxInferenceSession> createSessionFromFile(
    String filePath, {
    OrtSessionOptions? options,
  }) async {
    final session = await _runtime.createSession(filePath, options: options);
    return OnnxInferenceSession(session);
  }

  @override
  Future<OnnxTensor> createTensor(dynamic data, List<int> shape) async {
    final value = await OrtValue.fromList(data, shape);
    return OnnxTensor(value);
  }
}
