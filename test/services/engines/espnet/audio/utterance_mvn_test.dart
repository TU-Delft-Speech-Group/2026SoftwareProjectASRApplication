import 'dart:typed_data';

import 'package:asr_application/services/engines/espnet/audio/utterance_mvn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mvn = UtteranceMvn();

  group('UtteranceMvn', () {
    test('returns empty list for no frames', () {
      expect(mvn.apply(<Float32List>[]), isEmpty);
    });

    test('subtracts per-dimension mean across time', () {
      final frames = [
        Float32List.fromList([1.0, 10.0]),
        Float32List.fromList([3.0, 20.0]),
        Float32List.fromList([5.0, 30.0]),
      ];

      final result = mvn.apply(frames);

      // mean per dim is [3.0, 20.0]
      expect(result[0][0], closeTo(-2.0, 1e-6));
      expect(result[0][1], closeTo(-10.0, 1e-6));
      expect(result[1][0], closeTo(0.0, 1e-6));
      expect(result[1][1], closeTo(0.0, 1e-6));
      expect(result[2][0], closeTo(2.0, 1e-6));
      expect(result[2][1], closeTo(10.0, 1e-6));
    });

    test('does not mutate the input frames', () {
      final frames = [
        Float32List.fromList([1.0, 2.0]),
        Float32List.fromList([3.0, 4.0]),
      ];

      mvn.apply(frames);

      expect(frames[0].toList(), [1.0, 2.0]);
      expect(frames[1].toList(), [3.0, 4.0]);
    });

    test('post-normalized mean per dimension is approximately zero', () {
      final frames = List<Float32List>.generate(
        50,
        (i) => Float32List.fromList([i * 1.5, -i * 0.3, 100.0 + i]),
      );

      final result = mvn.apply(frames);

      for (var d = 0; d < 3; d++) {
        var sum = 0.0;
        for (final frame in result) {
          sum += frame[d];
        }
        expect(sum / result.length, closeTo(0.0, 1e-4));
      }
    });
  });
}
