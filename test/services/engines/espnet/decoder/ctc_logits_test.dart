import 'dart:math';
import 'dart:typed_data';

import 'package:asr_application/services/engines/espnet/decoder/ctc_logits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogMath.logAdd', () {
    test('returns the other operand when one is logZero', () {
      expect(LogMath.logAdd(LogMath.logZero, -2.5), -2.5);
      expect(LogMath.logAdd(-1.3, LogMath.logZero), -1.3);
    });

    test('matches log(exp(a) + exp(b)) within tolerance', () {
      final result = LogMath.logAdd(-1.0, -2.0);
      final expected = log(exp(-1.0) + exp(-2.0));
      expect((result - expected).abs(), lessThan(1e-12));
    });

    test('is symmetric', () {
      final ab = LogMath.logAdd(-3.0, -0.5);
      final ba = LogMath.logAdd(-0.5, -3.0);
      expect((ab - ba).abs(), lessThan(1e-12));
    });
  });

  group('LogMath.logSoftmaxAllFrames', () {
    test('produces rows whose probabilities sum to 1', () {
      const layout = CtcLogitsLayout(time: 2, vocab: 4);
      final logits = <double>[
        1.0, 2.0, 0.5, -1.0,
        -2.0, 0.0, 3.0, 1.5,
      ];
      final out = LogMath.logSoftmaxAllFrames(logits, layout);
      for (int t = 0; t < layout.time; t++) {
        double sum = 0.0;
        for (int v = 0; v < layout.vocab; v++) {
          sum += exp(out[t * layout.vocab + v]);
        }
        expect((sum - 1.0).abs(), lessThan(1e-9));
      }
    });

    test('is invariant under a constant shift per frame', () {
      const layout = CtcLogitsLayout(time: 1, vocab: 3);
      final a = LogMath.logSoftmaxAllFrames([1.0, 2.0, 3.0], layout);
      final b = LogMath.logSoftmaxAllFrames([11.0, 12.0, 13.0], layout);
      for (int v = 0; v < 3; v++) {
        expect((a[v] - b[v]).abs(), lessThan(1e-12));
      }
    });

    test('renormalizes inputs that are already log-softmax', () {
      const layout = CtcLogitsLayout(time: 1, vocab: 3);
      final input = [log(0.2), log(0.5), log(0.3)];
      final out = LogMath.logSoftmaxAllFrames(input, layout);
      expect((exp(out[0]) - 0.2).abs(), lessThan(1e-9));
      expect((exp(out[1]) - 0.5).abs(), lessThan(1e-9));
      expect((exp(out[2]) - 0.3).abs(), lessThan(1e-9));
    });
  });

  group('LogMath.topTokenIdsAtFrame', () {
    test('returns the top-k indices regardless of input order', () {
      final logProbs = Float64List.fromList([0.1, -0.5, 2.0, -3.0, 1.5, 0.0]);
      final top = LogMath.topTokenIdsAtFrame(logProbs, 0, 6, 3);
      expect(top.toSet(), {0, 2, 4});
    });

    test('clamps to vocab when count exceeds vocab', () {
      final logProbs = Float64List.fromList([0.0, 1.0, -1.0]);
      final top = LogMath.topTokenIdsAtFrame(logProbs, 0, 3, 10);
      expect(top.length, 3);
      expect(top.toSet(), {0, 1, 2});
    });

    test('respects the base offset', () {
      final logProbs = Float64List.fromList([
        9.0, 9.0, 9.0,
        0.0, 2.0, 1.0,
      ]);
      final top = LogMath.topTokenIdsAtFrame(logProbs, 3, 3, 2);
      expect(top.toSet(), {1, 2});
    });

    test('throws when count is zero or negative', () {
      final logProbs = Float64List.fromList([0.0, 1.0, -1.0]);
      expect(
        () => LogMath.topTokenIdsAtFrame(logProbs, 0, 3, 0),
        throwsArgumentError,
      );
      expect(
        () => LogMath.topTokenIdsAtFrame(logProbs, 0, 3, -5),
        throwsArgumentError,
      );
    });

    test('throws when vocab is zero or negative', () {
      final logProbs = Float64List.fromList([0.0, 1.0, -1.0]);
      expect(
        () => LogMath.topTokenIdsAtFrame(logProbs, 0, 0, 3),
        throwsArgumentError,
      );
      expect(
        () => LogMath.topTokenIdsAtFrame(logProbs, 0, -2, 3),
        throwsArgumentError,
      );
    });
  });

}
