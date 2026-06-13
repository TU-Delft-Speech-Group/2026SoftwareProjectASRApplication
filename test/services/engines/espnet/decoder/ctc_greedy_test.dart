import 'package:asr_application/services/engines/espnet/decoder/ctc_greedy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Vocab: 0 = blank, 1 = 'a', 2 = 'b', 3 = eos.
  const vocab = 4;
  List<double> peak(int id) {
    final f = List<double>.filled(vocab, -10.0);
    f[id] = 0.0;
    return f;
  }

  test('collapses repeated peaks into a single token', () {
    final logProbs = [...peak(1), ...peak(1), ...peak(2)];
    final ids = CtcGreedyDecoder.decode(
      logProbs,
      shape: const [3, vocab],
      blankId: 0,
    );
    expect(ids, [1, 2]);
  });

  test('keeps repeats that are separated by a blank', () {
    final logProbs = [...peak(1), ...peak(0), ...peak(1)];
    final ids = CtcGreedyDecoder.decode(
      logProbs,
      shape: const [3, vocab],
      blankId: 0,
    );
    expect(ids, [1, 1]);
  });

  test('drops the eos token from the output', () {
    final logProbs = [...peak(1), ...peak(3), ...peak(2)];
    final ids = CtcGreedyDecoder.decode(
      logProbs,
      shape: const [3, vocab],
      blankId: 0,
      eosId: 3,
    );
    expect(ids, [1, 2]);
  });

  test('returns an empty sequence when every frame is blank', () {
    final logProbs = [...peak(0), ...peak(0), ...peak(0)];
    final ids = CtcGreedyDecoder.decode(
      logProbs,
      shape: const [3, vocab],
      blankId: 0,
    );
    expect(ids, isEmpty);
  });

  test('accepts a 3D batch-first shape', () {
    final logProbs = [...peak(1), ...peak(2)];
    final ids = CtcGreedyDecoder.decode(
      logProbs,
      shape: const [1, 2, vocab],
      blankId: 0,
    );
    expect(ids, [1, 2]);
  });
}
