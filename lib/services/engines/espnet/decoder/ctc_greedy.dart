import 'dart:typed_data';

import 'ctc_logits.dart';

class CtcGreedyDecoder {
  static Int32List decode(
    List<double> logProbs, {
    required List<int> shape,
    required int blankId,
    int? eosId,
  }) {
    final layout = CtcLogitsLayout.fromShape(shape);
    layout.validateLogitsLength(logProbs.length);
    final time = layout.time;
    final vocab = layout.vocab;
    final out = <int>[];
    int previous = -1;

    for (int t = 0; t < time; t++) {
      final base = t * vocab;
      int bestId = 0;
      double bestValue = double.negativeInfinity;
      for (int v = 0; v < vocab; v++) {
        final value = logProbs[base + v];
        if (value > bestValue) {
          bestValue = value;
          bestId = v;
        }
      }

      if (bestId != blankId && bestId != previous && bestId != eosId) {
        out.add(bestId);
      }
      previous = bestId;
    }

    return Int32List.fromList(out);
  }
}
