import 'dart:math';
import 'dart:typed_data';

class CtcLogitsLayout {
  final int time;
  final int vocab;

  const CtcLogitsLayout({required this.time, required this.vocab});

  factory CtcLogitsLayout.fromShape(List<int> shape) {
    if (shape.length == 2) {
      return CtcLogitsLayout(time: shape[0], vocab: shape[1]);
    }
    if (shape.length == 3 && shape[0] == 1) {
      return CtcLogitsLayout(time: shape[1], vocab: shape[2]);
    }
    if (shape.length == 3 && shape[1] == 1) {
      return CtcLogitsLayout(time: shape[0], vocab: shape[2]);
    }
    throw ArgumentError('Unsupported CTC logits shape: $shape');
  }

  void validateLogitsLength(int length) {
    final expected = time * vocab;
    if (length != expected) {
      throw ArgumentError(
        'CTC logits length $length does not match layout '
        'time=$time vocab=$vocab (expected $expected)',
      );
    }
  }
}

class LogMath {
  static const double logZero = double.negativeInfinity;

  static double logAdd(double a, double b) {
    if (a == logZero) return b;
    if (b == logZero) return a;
    if (a >= b) return a + log(1.0 + exp(b - a));
    return b + log(1.0 + exp(a - b));
  }

  /// Re-normalizes even when the input is already log-softmax, so the decoder
  /// is robust to CTC heads that emit raw logits.
  static Float64List logSoftmaxAllFrames(
    List<double> logits,
    CtcLogitsLayout layout,
  ) {
    final time = layout.time;
    final vocab = layout.vocab;
    final out = Float64List(time * vocab);

    for (int t = 0; t < time; t++) {
      final base = t * vocab;
      double maxValue = double.negativeInfinity;
      for (int v = 0; v < vocab; v++) {
        final value = logits[base + v];
        out[base + v] = value;
        if (value > maxValue) maxValue = value;
      }

      double sumExp = 0.0;
      for (int v = 0; v < vocab; v++) {
        sumExp += exp(out[base + v] - maxValue);
      }
      final logSumExp = maxValue + log(sumExp);

      for (int v = 0; v < vocab; v++) {
        out[base + v] -= logSumExp;
      }
    }
    return out;
  }

  static Int32List topTokenIdsAtFrame(
    Float64List logProbs,
    int base,
    int vocab,
    int count,
  ) {
    if (count <= 0) {
      throw ArgumentError('count must be >= 1 (got $count)');
    }
    if (vocab <= 0) {
      throw ArgumentError('vocab must be >= 1 (got $vocab)');
    }
    final limit = count < vocab ? count : vocab;
    final heapIds = Int32List(limit);
    final heapVals = Float64List(limit);
    int heapSize = 0;

    for (int v = 0; v < vocab; v++) {
      final value = logProbs[base + v];

      if (heapSize < limit) {
        heapIds[heapSize] = v;
        heapVals[heapSize] = value;
        heapSize++;

        int i = heapSize - 1;
        while (i > 0) {
          final parent = (i - 1) >> 1;
          if (heapVals[parent] <= heapVals[i]) break;
          final tv = heapVals[parent];
          final ti = heapIds[parent];
          heapVals[parent] = heapVals[i];
          heapIds[parent] = heapIds[i];
          heapVals[i] = tv;
          heapIds[i] = ti;
          i = parent;
        }
        continue;
      }

      if (value <= heapVals[0]) continue;

      heapVals[0] = value;
      heapIds[0] = v;

      int i = 0;
      while (true) {
        final left = 2 * i + 1;
        final right = left + 1;
        int smallest = i;
        if (left < heapSize && heapVals[left] < heapVals[smallest]) {
          smallest = left;
        }
        if (right < heapSize && heapVals[right] < heapVals[smallest]) {
          smallest = right;
        }
        if (smallest == i) break;
        final tv = heapVals[i];
        final ti = heapIds[i];
        heapVals[i] = heapVals[smallest];
        heapIds[i] = heapIds[smallest];
        heapVals[smallest] = tv;
        heapIds[smallest] = ti;
        i = smallest;
      }
    }

    return heapIds;
  }
}
