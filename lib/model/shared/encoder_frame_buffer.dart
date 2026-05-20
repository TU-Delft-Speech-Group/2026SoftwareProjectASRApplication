import 'dart:typed_data';

/// A batch of precomputed feature frames for encoder inference.
///
/// Values are stored as one flattened float buffer and exposed to ONNX with the
/// shape `[1, frameCount, featureDimension]`.
class EncoderFrameBuffer {
  EncoderFrameBuffer({
    required this.values,
    required this.frameCount,
    required this.featureDimension,
  }) {
    final expectedLength = frameCount * featureDimension;
    if (values.length != expectedLength) {
      throw ArgumentError(
        'Frame buffer contains ${values.length} values, but '
        '$frameCount frames with $featureDimension features require '
        '$expectedLength values.',
      );
    }
  }

  factory EncoderFrameBuffer.fromFrames(List<Float32List> frames) {
    if (frames.isEmpty) {
      throw ArgumentError.value(frames, 'frames', 'Must contain frames.');
    }

    final featureDimension = frames.first.length;
    if (featureDimension == 0) {
      throw ArgumentError.value(
        frames,
        'frames',
        'Frames must contain feature values.',
      );
    }

    final flattened = Float32List(frames.length * featureDimension);
    var offset = 0;
    for (final frame in frames) {
      if (frame.length != featureDimension) {
        throw ArgumentError(
          'All frames must have the same feature dimension. Expected '
          '$featureDimension, got ${frame.length}.',
        );
      }
      flattened.setRange(offset, offset + featureDimension, frame);
      offset += featureDimension;
    }

    return EncoderFrameBuffer(
      values: flattened,
      frameCount: frames.length,
      featureDimension: featureDimension,
    );
  }

  final Float32List values;
  final int frameCount;
  final int featureDimension;

  List<int> get shape => [1, frameCount, featureDimension];
}
