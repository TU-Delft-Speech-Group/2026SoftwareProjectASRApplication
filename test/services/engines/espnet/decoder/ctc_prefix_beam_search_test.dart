import 'package:asr_application/services/engines/espnet/decoder/ctc_prefix_beam_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Vocab: 0 = blank, 1 = 'a', 2 = 'b', 3 = eos.
  const vocab = 4;
  List<double> peak(int id) {
    final f = List<double>.filled(vocab, -10.0);
    f[id] = 0.0;
    return f;
  }

  test('returns the obvious peaks path', () {
    final logProbs = [...peak(1), ...peak(0), ...peak(2)];
    final ids = CtcPrefixBeamSearch.decode(
      logProbs,
      shape: const [3, vocab],
      blankId: 0,
    );
    expect(ids, [1, 2]);
  });

  test('keeps repeats that are separated by a blank', () {
    final logProbs = [...peak(1), ...peak(0), ...peak(1)];
    final ids = CtcPrefixBeamSearch.decode(
      logProbs,
      shape: const [3, vocab],
      blankId: 0,
    );
    expect(ids, [1, 1]);
  });

  test('collapses immediate repeats with no blank between them', () {
    final logProbs = [...peak(1), ...peak(1), ...peak(2)];
    final ids = CtcPrefixBeamSearch.decode(
      logProbs,
      shape: const [3, vocab],
      blankId: 0,
    );
    expect(ids, [1, 2]);
  });

  test('suppressed tokens never appear in the result', () {
    final logProbs = [...peak(1), ...peak(0), ...peak(2)];
    final ids = CtcPrefixBeamSearch.decode(
      logProbs,
      shape: const [3, vocab],
      blankId: 0,
      suppressedTokenIds: const {2},
    );
    expect(ids, [1]);
  });

  test('strips a trailing eos token', () {
    final logProbs = [...peak(1), ...peak(0), ...peak(3)];
    final ids = CtcPrefixBeamSearch.decode(
      logProbs,
      shape: const [3, vocab],
      blankId: 0,
      eosId: 3,
    );
    expect(ids, [1]);
  });

  test('rejects a blankId outside the vocab', () {
    final logProbs = peak(1);
    expect(
      () => CtcPrefixBeamSearch.decode(
        logProbs,
        shape: const [1, vocab],
        blankId: 99,
      ),
      throwsArgumentError,
    );
  });

  test('runs with a beam smaller than the candidate set', () {
    final logProbs = [...peak(1), ...peak(2)];
    final ids = CtcPrefixBeamSearch.decode(
      logProbs,
      shape: const [2, vocab],
      blankId: 0,
      beamSize: 1,
      tokenPruneSize: 2,
    );
    expect(ids, [1, 2]);
  });
}
