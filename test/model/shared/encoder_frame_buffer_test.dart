import 'dart:typed_data';

import 'package:asr_application/model/shared/encoder_frame_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EncoderFrameBuffer', () {
    test('flattens frame data', () {
      final buffer = EncoderFrameBuffer.fromFrames([
        Float32List.fromList([1, 2, 3]),
        Float32List.fromList([4, 5, 6]),
      ]);

      expect(buffer.shape, [1, 2, 3]);
      expect(buffer.values.toList(), [1, 2, 3, 4, 5, 6]);
    });

    test('rejects frames of different sizes', () {
      expect(
        () => EncoderFrameBuffer.fromFrames([
          Float32List.fromList([1, 2]),
          Float32List.fromList([3]),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects an empty frame list', () {
      expect(
        () => EncoderFrameBuffer.fromFrames([]),
        throwsArgumentError,
      );
    });

    test('rejects frames with zero feature dimension', () {
      expect(
        () => EncoderFrameBuffer.fromFrames([Float32List(0)]),
        throwsArgumentError,
      );
    });
  });
}
