import 'dart:typed_data';
import 'package:asr_application/services/token_decoder/bpe_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/vocab_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /* vocab matching Dutch CGN special tokens:
    0 = <unk>
    1 = <s>
    2 = </s>
    3 = [FIL]
    4 = [LAUGH]
    5 = [UNK]
    6 = ▁
    7 = ▁ja
    8 = ▁ik
    9 = ▁de
    10 = t
    11 = en
  */
  final testVocab = [
    '<unk>',   // 0
    '<s>',     // 1
    '</s>',    // 2
    '[FIL]',   // 3
    '[LAUGH]', // 4
    '[UNK]',   // 5
    '▁',       // 6
    '▁ja',     // 7
    '▁ik',     // 8
    '▁de',     // 9
    't',       // 10
    'en',      // 11
  ];

  group('StubTokenIdToTextService', () {
    const stub = StubTokenIdToTextService();

    test('returns raw IDs joined by spaces', () async {
      final result = await stub.decode(Int32List.fromList([1, 2, 3]));
      expect(result.text, '1 2 3');
    });

    test('returns empty string for empty input', () async {
      final result = await stub.decode(Int32List.fromList([]));
      expect(result.text, '');
    });

    test('tokenIds in result match input', () async {
      final input = Int32List.fromList([10, 20, 30]);
      final result = await stub.decode(input);
      expect(result.tokenIds, input);
    });

    test('decodeToString matches result text', () async {
      final text = await stub.decodeToString(Int32List.fromList([1, 2]));
      expect(text, '1 2');
    });
  });

  group('BpeTokenIdToTextService', () {
    final service = BpeTokenIdToTextService.fromVocab(
      testVocab,
      config: VocabConfig.dutch,
    );

    test('filters out unk, sos, eos special tokens', () async {
      final result = await service.decode(Int32List.fromList([0, 1, 2]));
      expect(result.text, '');
      expect(result.tokenIds, isEmpty);
    });

    test('filters out suppressed filler tokens', () async {
      final result = await service.decode(Int32List.fromList([3, 4, 5]));
      expect(result.text, '');
      expect(result.tokenIds, isEmpty);
    });

    test('replaces word boundary marker with space', () async {
      final result = await service.decode(Int32List.fromList([7, 8]));
      expect(result.text, 'ja ik');
    });

    test('trims leading and trailing whitespace', () async {
      final result = await service.decode(Int32List.fromList([7]));
      expect(result.text, 'ja');
    });

    test('collapses double spaces', () async {
      // 6=▁ alone between words produces a double space before collapsing
      final result = await service.decode(Int32List.fromList([7, 6, 8]));
      expect(result.text, 'ja ik');
    });

    test('returns unknown marker for out of range IDs', () async {
      final result = await service.decode(Int32List.fromList([999]));
      expect(result.text, '[unk:999]');
    });

    test('returns empty for empty input', () async {
      final result = await service.decode(Int32List.fromList([]));
      expect(result.text, '');
      expect(result.tokenIds, isEmpty);
    });

    test('filteredIds excludes suppressed tokens', () async {
      final result = await service.decode(Int32List.fromList([1, 7, 2]));
      expect(result.tokenIds, Int32List.fromList([7]));
    });

    test('decodeToString matches result text', () async {
      final text = await service.decodeToString(Int32List.fromList([7, 8]));
      expect(text, 'ja ik');
    });
  });

  group('BpeTokenIdToTextService - asset loading', () {
    test('loads vocab from asset file and decodes correctly', () async {
      final service = await BpeTokenIdToTextService.load(
        'test/services/token_decoder/test_vocab.txt',
        config: VocabConfig.dutch,
      );
      final result = await service.decode(Int32List.fromList([7, 8]));
      expect(result.text, 'ja ik');
    });

    test('loaded service filters special tokens', () async {
      final service = await BpeTokenIdToTextService.load(
        'test/services/token_decoder/test_vocab.txt',
        config: VocabConfig.dutch,
      );
      final result = await service.decode(Int32List.fromList([0, 1, 2, 7]));
      expect(result.text, 'ja');
    });
  });

  group('VocabConfig.dutch', () {
    test('suppresses unk, sos, eos', () {
      expect(VocabConfig.dutch.isSuppressed(0), isTrue);
      expect(VocabConfig.dutch.isSuppressed(1), isTrue);
      expect(VocabConfig.dutch.isSuppressed(2), isTrue);
    });

    test('suppresses filler tokens', () {
      expect(VocabConfig.dutch.isSuppressed(3), isTrue);
      expect(VocabConfig.dutch.isSuppressed(4), isTrue);
      expect(VocabConfig.dutch.isSuppressed(5), isTrue);
    });

    test('does not suppress regular tokens', () {
      expect(VocabConfig.dutch.isSuppressed(6), isFalse);
      expect(VocabConfig.dutch.isSuppressed(100), isFalse);
    });

    test('uses sentencepiece word boundary marker', () {
      expect(VocabConfig.dutch.wordBoundaryMarker, '▁');
    });
  });

  group('VocabConfig.english', () {
    test('suppresses unk, sos, eos', () {
      expect(VocabConfig.english.isSuppressed(0), isTrue);
      expect(VocabConfig.english.isSuppressed(1), isTrue);
      expect(VocabConfig.english.isSuppressed(2), isTrue);
    });

    test('does not suppress regular tokens', () {
      expect(VocabConfig.english.isSuppressed(3), isFalse);
      expect(VocabConfig.english.isSuppressed(100), isFalse);
    });

    test('uses sentencepiece word boundary marker', () {
      expect(VocabConfig.english.wordBoundaryMarker, '▁');
    });
  });
}
