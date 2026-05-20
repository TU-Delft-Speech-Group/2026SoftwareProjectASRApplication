import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'onnx_inference_contracts.dart';
import 'onnx_tensor.dart';

/// Wrapper around an ONNX Runtime session.
class OnnxInferenceSession implements OnnxInferenceSessionContract {
  OnnxInferenceSession(this._session);

  final OrtSession _session;

  @override
  Future<Map<String, OnnxTensor>> run(
    Map<String, OnnxTensorContract> inputs,
  ) async {
    final onnxInputs = inputs.map((name, value) {
      if (value is! OnnxTensor) {
        throw ArgumentError('OnnxInferenceSession requires OnnxTensor inputs.');
      }
      return MapEntry(name, value.value);
    });

    final outputs = await _session.run(onnxInputs);
    return outputs.map((name, value) => MapEntry(name, OnnxTensor(value)));
  }

  @override
  Future<void> close() => _session.close();
}
