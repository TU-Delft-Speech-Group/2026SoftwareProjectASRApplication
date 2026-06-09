import 'package:asr_application/domain/models/model/model_metadata.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsrModelConfig.fromMetadata', () {
    const dutchMeta = ModelMetadata(
      blankId: 0,
      unkId: 1,
      sosEosId: 4999,
      suppressedIds: {0, 2, 3, 4},
      wordBoundaryMarker: '▁',
    );

    test('maps metadata onto config scalar fields', () {
      final config = AsrModelConfig.fromMetadata(dutchMeta);

      expect(config.blankId, 0);
      expect(config.eosId, 4999);
      expect(config.beamSize, 1);
    });

    test('builds a VocabConfig that suppresses the filler tokens', () {
      final vocab = AsrModelConfig.fromMetadata(dutchMeta).vocabConfig;

      expect(vocab.unkId, 1);
      expect(vocab.sosId, 4999);
      expect(vocab.eosId, 4999);
      expect(vocab.wordBoundaryMarker, '▁');
      // unk/sos/eos plus the bracketed fillers are all filtered.
      expect(vocab.isSuppressed(0), isTrue); // blank
      expect(vocab.isSuppressed(2), isTrue); // [FIL]
      expect(vocab.isSuppressed(4), isTrue); // [UNK]
      expect(vocab.isSuppressed(4999), isTrue); // sos/eos
      expect(vocab.isSuppressed(10), isFalse); // a real token
    });

    test('honors a null word-boundary marker', () {
      const noMarker = ModelMetadata(
        blankId: 0,
        unkId: 1,
        sosEosId: 99,
        suppressedIds: {0},
      );

      final vocab = AsrModelConfig.fromMetadata(noMarker).vocabConfig;

      expect(vocab.wordBoundaryMarker, isNull);
    });
  });
}
