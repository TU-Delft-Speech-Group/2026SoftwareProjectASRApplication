import 'dart:typed_data';

/// Raw CTC model output for token probability decoding.
///
/// `values` contains the flattened CTC tensor and `shape` preserves the ONNX
/// output dimensions for the decoder to interpret.
class CtcOutput {
  const CtcOutput({required this.values, required this.shape});

  final Float32List values;
  final List<int> shape;
}
