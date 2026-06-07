import 'dart:typed_data';

/// Raw CTC model output for token probability decoding.
///
/// `values` contains the flattened CTC tensor and `shape` preserves the ONNX
/// output dimensions for the decoder to interpret.
class CtcOutput {
  CtcOutput({required this.values, required this.shape}) {
    if (shape.length != 3) {
      throw ArgumentError(
        'CTC output shape must be 3-dimensional [batch, time, vocab], '
        'got ${shape.length} dimension(s): $shape.',
      );
    }
    if (shape.any((d) => d <= 0)) {
      throw ArgumentError(
        'CTC output shape dimensions must all be positive, got $shape.',
      );
    }
    final expected = shape.reduce((a, b) => a * b);
    if (values.length != expected) {
      throw ArgumentError(
        'CTC output values length ${values.length} does not match '
        'shape $shape (expected $expected values).',
      );
    }
  }

  final Float32List values;
  final List<int> shape;
}
