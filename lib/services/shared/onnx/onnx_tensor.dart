import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'onnx_inference_contracts.dart';

/// Wrapper around an ONNX Runtime tensor value.
class OnnxTensor implements OnnxTensorContract {
  const OnnxTensor(this.value);

  final OrtValue value;

  @override
  List<int> get shape => value.shape;

  @override
  Future<Float32List> asFloat32List() async {
    final values = await value.asFlattenedList();
    return Float32List.fromList(
      values.map((value) {
        if (value is! num) {
          throw StateError(
            'Expected numeric ONNX output, got ${value.runtimeType}.',
          );
        }
        return value.toDouble();
      }).toList(),
    );
  }

  @override
  Future<List<dynamic>> asList() => value.asFlattenedList();

  @override
  Future<void> dispose() => value.dispose();
}
