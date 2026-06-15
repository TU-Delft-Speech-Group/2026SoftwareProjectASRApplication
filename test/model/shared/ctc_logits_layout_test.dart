import 'package:asr_application/model/shared/ctc_logits_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CtcLogitsLayout.validateLogitsLength', () {
    test('accepts a buffer of length time * vocab', () {
      const layout = CtcLogitsLayout(time: 3, vocab: 4);
      layout.validateLogitsLength(12);
    });

    test('throws on a mismatched buffer length', () {
      const layout = CtcLogitsLayout(time: 3, vocab: 4);
      expect(() => layout.validateLogitsLength(11), throwsArgumentError);
      expect(() => layout.validateLogitsLength(13), throwsArgumentError);
    });
  });

  group('CtcLogitsLayout.fromShape', () {
    test('parses 2D shape', () {
      final l = CtcLogitsLayout.fromShape(const [5, 10]);
      expect(l.time, 5);
      expect(l.vocab, 10);
    });

    test('parses 3D batch-first shape', () {
      final l = CtcLogitsLayout.fromShape(const [1, 7, 12]);
      expect(l.time, 7);
      expect(l.vocab, 12);
    });

    test('parses 3D time-first shape', () {
      final l = CtcLogitsLayout.fromShape(const [7, 1, 12]);
      expect(l.time, 7);
      expect(l.vocab, 12);
    });

    test('throws on unsupported shapes', () {
      expect(
        () => CtcLogitsLayout.fromShape(const [2, 3, 4]),
        throwsArgumentError,
      );
      expect(
        () => CtcLogitsLayout.fromShape(const [4]),
        throwsArgumentError,
      );
    });
  });
}
