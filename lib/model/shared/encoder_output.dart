import 'dart:typed_data';

/// Raw encoder output passed from the encoder service to the CTC service.
///
/// `values` contains the flattened encoder tensor, while `shape` preserves the
/// original ONNX output dimensions for the next pipeline step (CTC) to
/// interpret.
class EncoderOutput {
  const EncoderOutput({
    required this.values,
    required this.shape,
    this.encodedFrameCount,
  });

  final Float32List values;
  final List<int> shape;
  final int? encodedFrameCount;
}
