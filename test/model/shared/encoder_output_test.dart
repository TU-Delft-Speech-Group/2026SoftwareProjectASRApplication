import 'dart:typed_data';

import 'package:asr_application/model/shared/encoder_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EncoderOutput', () {
    test('accepts a valid 3D shape with matching values', () {
      final output = EncoderOutput(
        values: Float32List.fromList([1, 2, 3, 4, 5, 6]),
        shape: [1, 2, 3],
      );
      expect(output.values.length, 6);
      expect(output.shape, [1, 2, 3]);
    });

    test('accepts an optional encodedFrameCount', () {
      final output = EncoderOutput(
        values: Float32List.fromList([1, 2]),
        shape: [1, 1, 2],
        encodedFrameCount: 1,
      );
      expect(output.encodedFrameCount, 1);
    });

    group('rejects invalid shapes', () {
      test('throws when shape is 2-dimensional', () {
        expect(
          () => EncoderOutput(
            values: Float32List.fromList([1, 2]),
            shape: [1, 2],
          ),
          throwsArgumentError,
        );
      });

      test('throws when shape is 4-dimensional', () {
        expect(
          () => EncoderOutput(
            values: Float32List.fromList([1, 2]),
            shape: [1, 1, 1, 2],
          ),
          throwsArgumentError,
        );
      });

      test('throws when a shape dimension is zero', () {
        expect(
          () => EncoderOutput(
            values: Float32List(0),
            shape: [1, 0, 4],
          ),
          throwsArgumentError,
        );
      });

      test('throws when a shape dimension is negative', () {
        expect(
          () => EncoderOutput(
            values: Float32List(0),
            shape: [1, -1, 4],
          ),
          throwsArgumentError,
        );
      });

      test('throws when values length does not match shape product', () {
        expect(
          () => EncoderOutput(
            values: Float32List.fromList([1, 2, 3]),
            shape: [1, 2, 3],
          ),
          throwsArgumentError,
        );
      });
    });
  });
}
