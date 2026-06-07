import 'dart:typed_data';

/// Raw encoder output passed from the encoder service to the CTC service.
///
/// `values` contains the flattened encoder tensor, while `shape` preserves the
/// original ONNX output dimensions for the next pipeline step (CTC) to
/// interpret.
class EncoderOutput {
  EncoderOutput({
    required this.values,
    required this.shape,
    this.encodedFrameCount,
  }) {
    if (shape.length != 3) {
      throw ArgumentError(
        'Encoder output shape must be 3-dimensional [batch, time, features], '
        'got ${shape.length} dimension(s): $shape.',
      );
    }
    if (shape.any((d) => d <= 0)) {
      throw ArgumentError(
        'Encoder output shape dimensions must all be positive, got $shape.',
      );
    }
    final expected = shape.reduce((a, b) => a * b);
    if (values.length != expected) {
      throw ArgumentError(
        'Encoder output values length ${values.length} does not match '
        'shape $shape (expected $expected values).',
      );
    }
  }

  final Float32List values;
  final List<int> shape;
  final int? encodedFrameCount;
}
