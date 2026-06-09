import 'package:flutter_test/flutter_test.dart';

import 'wer.dart';

void main() {
  group('scoreTranscript', () {
    test('returns zero error for an exact match', () {
      final s = scoreTranscript('hello world', 'hello world');
      expect(s.wer, 0.0);
      expect(s.cer, 0.0);
      expect(s.substitutions + s.insertions + s.deletions, 0);
    });

    test('is case-insensitive and ignores ASCII punctuation', () {
      final s = scoreTranscript('Hello, World!', 'hello world');
      expect(s.wer, 0.0);
      expect(s.cer, 0.0);
    });

    test('collapses repeated whitespace before scoring', () {
      final s = scoreTranscript('hello   world', 'hello world');
      expect(s.wer, 0.0);
    });

    test('counts a substitution as one word error', () {
      final s = scoreTranscript('the quick brown fox', 'the slow brown fox');
      expect(s.substitutions, 1);
      expect(s.insertions, 0);
      expect(s.deletions, 0);
      expect(s.wer, closeTo(0.25, 1e-9));
    });

    test('counts an insertion as one word error', () {
      final s = scoreTranscript('the brown fox', 'the very brown fox');
      expect(s.insertions, 1);
      expect(s.substitutions, 0);
      expect(s.deletions, 0);
      expect(s.wer, closeTo(1 / 3, 1e-9));
    });

    test('counts a deletion as one word error', () {
      final s = scoreTranscript('the quick brown fox', 'the brown fox');
      expect(s.deletions, 1);
      expect(s.substitutions, 0);
      expect(s.insertions, 0);
      expect(s.wer, closeTo(0.25, 1e-9));
    });

    test('WER can exceed 1.0 when hypothesis is much longer', () {
      final s = scoreTranscript('hi', 'hi there friend');
      expect(s.wer, greaterThan(1.0));
    });

    test('empty hypothesis against non-empty reference scores WER 1.0', () {
      final s = scoreTranscript('hello world', '');
      expect(s.wer, 1.0);
      expect(s.deletions, 2);
    });

    test('empty reference and empty hypothesis score zero', () {
      final s = scoreTranscript('', '');
      expect(s.wer, 0.0);
      expect(s.cer, 0.0);
    });

    test('empty reference with non-empty hypothesis scores WER 1.0', () {
      // Avoids division-by-zero; signals that any output is wrong.
      final s = scoreTranscript('', 'unexpected');
      expect(s.wer, 1.0);
      expect(s.cer, 1.0);
    });

    test('CER is finer-grained than WER for near-miss substitutions', () {
      final s = scoreTranscript('kitten', 'sitten');
      expect(s.wer, 1.0);
      expect(s.cer, closeTo(1 / 6, 1e-9));
    });

    test('referenceWords reflects the normalised reference length', () {
      final s = scoreTranscript('Hello, world!', 'hello world');
      expect(s.referenceWords, 2);
    });
  });
}
