import 'dart:typed_data';

import 'ctc_logits_layout.dart';

/// Raw CTC model output for token probability decoding.
///
/// `values` contains the flattened CTC tensor and `shape` preserves the ONNX
/// output dimensions for the decoder to interpret.
class CtcOutput {
  CtcOutput({required this.values, required this.shape}) {
    final layout = CtcLogitsLayout.fromShape(shape);
    layout.validateLogitsLength(values.length);
  }

  final Float32List values;
  final List<int> shape;
}
