import 'dart:typed_data';

import 'package:asr_application/model/shared/ctc_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CtcOutput', () {
    test('accepts a valid 3D batch-first shape with matching values', () {
      final output = CtcOutput(
        values: Float32List.fromList([1, 2, 3, 4, 5, 6]),
        shape: [1, 2, 3],
      );
      expect(output.values.length, 6);
      expect(output.shape, [1, 2, 3]);
    });

    test('accepts a valid 2D shape with matching values', () {
      final output = CtcOutput(
        values: Float32List.fromList([1, 2, 3, 4, 5, 6]),
        shape: [2, 3],
      );
      expect(output.values.length, 6);
      expect(output.shape, [2, 3]);
    });

    group('rejects invalid shapes', () {
      test('throws when shape is 4-dimensional', () {
        expect(
          () => CtcOutput(
            values: Float32List.fromList([1, 2]),
            shape: [1, 1, 1, 2],
          ),
          throwsArgumentError,
        );
      });

      test('throws when shape is 1-dimensional', () {
        expect(
          () => CtcOutput(
            values: Float32List.fromList([1, 2]),
            shape: [2],
          ),
          throwsArgumentError,
        );
      });

      test('throws when values length does not match shape product', () {
        expect(
          () => CtcOutput(
            values: Float32List.fromList([1, 2, 3]),
            shape: [1, 2, 5000],
          ),
          throwsArgumentError,
        );
      });
    });
  });
}
