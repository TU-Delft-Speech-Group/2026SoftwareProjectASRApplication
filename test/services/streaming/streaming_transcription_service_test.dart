import 'dart:typed_data';

import 'package:asr_application/services/decoder/decoder_service.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'package:flutter_test/flutter_test.dart';

/* always returns the same fixed text regardless of token ids */
class _FixedTextService implements TokenIdToTextService {
  const _FixedTextService(this._text);
  final String _text;

  @override
  Future<DecodeResult> decode(Int32List tokenIds) async =>
      DecodeResult(text: _text, tokenIds: tokenIds);
}

StreamingTranscriptionService _serviceWithText(String text, {int agreementN = 2}) =>
    StreamingTranscriptionService(
      encode: _fakeEncode,
      decoder: const DecoderService(blankId: 0),
      textService: _FixedTextService(text),
      policy: LocalAgreementPolicy(n: agreementN),
    );

/* encode: shape [3, 3], three time steps, vocab size 3;
  t=0 strongly predicts token 1 (non-blank)
  t=1 strongly predicts token 0 (blank)
  t=2 strongly predicts token 2 (non-blank)
  CTC collapse of [blank=0, 1, 2] produces [1, 2];
  StubTokenIdToTextService joins with spaces, giving "1 2"
*/
Future<(List<double>, List<int>)> _fakeEncode(List<Float32List> _) async =>
    (
      const <double>[
        -100, 0, -100, // t=0: token 1
        0, -100, -100, // t=1: blank
        -100, -100, 0, // t=2: token 2
      ],
      const <int>[3, 3],
    );

StreamingTranscriptionService _service({
  int agreementN = 2,
  EncodeBuffer? encode,
}) =>
    StreamingTranscriptionService(
      encode: encode ?? _fakeEncode,
      decoder: const DecoderService(blankId: 0),
      textService: const StubTokenIdToTextService(),
      policy: LocalAgreementPolicy(n: agreementN),
    );

// one dummy frame (content does not matter since _fakeEncode ignores input)
final _dummyFrame = Float32List.fromList([0.0]);

void main() {
  group('StreamingTranscriptionService', () {
    group('process', () {
      test('returns null when no new frames are provided', () async {
        final service = _service();

        final result = await service.process([]);

        expect(result, isNull);
      });

      test('returns null when called again with the same frame list', () async {
        final service = _service();
        await service.process([_dummyFrame]);

        final result = await service.process([_dummyFrame]);

        expect(result, isNull);
      });

      test('processes only newly added frames on subsequent calls', () async {
        final service = _service();

        await service.process([_dummyFrame]);
        final result = await service.process([_dummyFrame, _dummyFrame]);

        // one new frame was added,a result is expected
        expect(result, isNotNull);
      });

      test('returns a StreamResult with hypothesis on first chunk', () async {
        final service = _service();

        final result = await service.process([_dummyFrame]);

        expect(result, isNotNull);
        expect(result!.hypothesis, isNotEmpty);
        expect(result.confirmedText, isEmpty);
      });

      test('confirms a prefix after n agreeing chunks', () async {
        final service = _service(agreementN: 2);

        // chunk 1,no agreement yet (only 1 transcript in history)
        final r1 = await service.process([_dummyFrame]);
        expect(r1!.confirmedText, isEmpty);

        // chunk 2,same hypothesis again, LocalAgreement (2) 
        final r2 = await service.process([_dummyFrame, _dummyFrame]);
        expect(r2!.confirmedText, isNotEmpty);
      });

      test('confirmed text is a word-boundary prefix of the hypothesis', () async {
        final service = _service(agreementN: 2);

        await service.process([_dummyFrame]);
        final r2 = await service.process([_dummyFrame, _dummyFrame]);

        expect(
          r2!.hypothesis,
          startsWith(r2.confirmedText),
          reason: 'confirmed text must be a prefix of the hypothesis',
        );
      });

      test('exposes confirmed text via getter between calls', () async {
        final service = _service(agreementN: 2);

        await service.process([_dummyFrame]);
        expect(service.confirmedText, isEmpty);

        await service.process([_dummyFrame, _dummyFrame]);
        expect(service.confirmedText, isNotEmpty);
      });
    });

    group('buffer scroll on sentence confirmation', () {
      test('sets sentenceConfirmed when confirmed prefix ends with a period',
          () async {
        final service = _serviceWithText('hello.');

        await service.process([_dummyFrame]);
        final result = await service.process([_dummyFrame, _dummyFrame]);

        expect(result!.sentenceConfirmed, isTrue);
        expect(result.confirmedText, equals('hello.'));
      });

      test('sets sentenceConfirmed for question and exclamation marks',
          () async {
        for (final punct in ['?', '!']) {
          final service = _serviceWithText('word$punct');
          await service.process([_dummyFrame]);
          final r = await service.process([_dummyFrame, _dummyFrame]);
          expect(r!.sentenceConfirmed, isTrue,
              reason: 'expected sentenceConfirmed for "$punct"');
        }
      });

      test('does not set sentenceConfirmed for non-sentence-final text',
          () async {
        final service = _serviceWithText('hello world');

        await service.process([_dummyFrame]);
        final result = await service.process([_dummyFrame, _dummyFrame]);

        expect(result!.sentenceConfirmed, isFalse);
      });

      test('resets confirmedText after scroll', () async {
        final service = _serviceWithText('done.');

        await service.process([_dummyFrame]);
        await service.process([_dummyFrame, _dummyFrame]);

        expect(service.confirmedText, isEmpty);
      });

      test('does not re-process old frames after scroll', () async {
        final service = _serviceWithText('done.');

        await service.process([_dummyFrame]);
        await service.process([_dummyFrame, _dummyFrame]); // scroll; watermark=2

        // same frame list, no new frames beyond watermark
        final result = await service.process([_dummyFrame, _dummyFrame]);
        expect(result, isNull);
      });

      test('processes only new frames after scroll', () async {
        final service = _serviceWithText('done.');

        await service.process([_dummyFrame]);
        await service.process([_dummyFrame, _dummyFrame]); // scroll; watermark=2

        // one new frame, should produce a result
        final result = await service.process([
          _dummyFrame,
          _dummyFrame,
          _dummyFrame,
        ]);
        expect(result, isNotNull);
        // history has only one entry after scroll, no confirmation yet
        expect(result!.sentenceConfirmed, isFalse);
        expect(result.confirmedText, isEmpty);
      });
    });

    group('reset', () {
      test('clears confirmed text', () async {
        final service = _service(agreementN: 2);
        await service.process([_dummyFrame]);
        await service.process([_dummyFrame, _dummyFrame]);
        expect(service.confirmedText, isNotEmpty);

        service.reset();

        expect(service.confirmedText, isEmpty);
      });

      test('restarts frame watermark so old frames are re-processed', () async {
        final service = _service();
        await service.process([_dummyFrame]);
        service.reset();

        // same list again,after reset the watermark is 0, so this is new
        final result = await service.process([_dummyFrame]);
        expect(result, isNotNull);
      });

      test('clears transcript history so agreement does not span resets',
          () async {
        final service = _service(agreementN: 2);
        await service.process([_dummyFrame]);
        service.reset();

        // first chunk after reset,history is cleared, no agreement possible
        final result = await service.process([_dummyFrame]);
        expect(result!.confirmedText, isEmpty);
      });
    });
  });
}
