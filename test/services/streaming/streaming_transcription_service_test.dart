import 'dart:typed_data';

import 'package:asr_application/exceptions/pipeline/pipeline_stage_exception.dart';
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
Future<(List<double>, List<int>, TransformerDecoderRunner?)> _fakeEncode(
  List<Float32List> _,
) async =>
    (
      const <double>[
        -100, 0, -100, // t=0: token 1
        0, -100, -100, // t=1: blank
        -100, -100, 0, // t=2: token 2
      ],
      const <int>[3, 3],
      null,
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

      test('returns an OngoingResult with hypothesis on first chunk', () async {
        final service = _service();

        final result = await service.process([_dummyFrame]);

        expect(result, isNotNull);
        expect(result, isA<OngoingResult>());
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
      test('emits SegmentResult when confirmed prefix ends with a period',
          () async {
        final service = _serviceWithText('hello.');

        await service.process([_dummyFrame]);
        final result = await service.process([_dummyFrame, _dummyFrame]);

        expect(result, isA<SegmentResult>());
        expect(result!.confirmedText, equals('hello.'));
      });

      test('emits SegmentResult for question and exclamation marks', () async {
        for (final punct in ['?', '!']) {
          final service = _serviceWithText('word$punct');
          await service.process([_dummyFrame]);
          final r = await service.process([_dummyFrame, _dummyFrame]);
          expect(r, isA<SegmentResult>(),
              reason: 'expected SegmentResult for "$punct"');
        }
      });

      test('emits OngoingResult for non-sentence-final text', () async {
        final service = _serviceWithText('hello world');

        await service.process([_dummyFrame]);
        final result = await service.process([_dummyFrame, _dummyFrame]);

        expect(result, isA<OngoingResult>());
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
        expect(result, isA<OngoingResult>());
        expect(result!.confirmedText, isEmpty);
      });
    });

    group('buffer cap auto-commit', () {
      test('emits SegmentResult when buffer reaches maxBufferFrames', () async {
        final service = StreamingTranscriptionService(
          encode: _fakeEncode,
          decoder: const DecoderService(blankId: 0),
          textService: const _FixedTextService('hello world'),
          policy: const LocalAgreementPolicy(n: 2),
          maxBufferFrames: 2,
        );

        await service.process([_dummyFrame]);
        final result = await service.process([_dummyFrame, _dummyFrame]);

        expect(result, isA<SegmentResult>());
        expect(result!.confirmedText, equals('hello world'));
      });

      test('falls back to the last hypothesis when nothing was confirmed',
          () async {
        final service = StreamingTranscriptionService(
          encode: _fakeEncode,
          decoder: const DecoderService(blankId: 0),
          textService: const _FixedTextService('hello world'),
          policy: const LocalAgreementPolicy(n: 5),
          maxBufferFrames: 1,
        );

        final result = await service.process([_dummyFrame]);

        expect(result, isA<SegmentResult>());
        expect(result!.confirmedText, equals('hello world'));
      });

      test('resets buffer state so the next call starts a new segment',
          () async {
        final service = StreamingTranscriptionService(
          encode: _fakeEncode,
          decoder: const DecoderService(blankId: 0),
          textService: const _FixedTextService('hello world'),
          policy: const LocalAgreementPolicy(n: 5),
          maxBufferFrames: 1,
        );

        await service.process([_dummyFrame]);

        expect(service.confirmedText, isEmpty);
      });
    });

    group('commit', () {
      test('clears confirmed text and history but preserves the watermark',
          () async {
        final service = _service(agreementN: 2);
        await service.process([_dummyFrame]);
        await service.process([_dummyFrame, _dummyFrame]);
        expect(service.confirmedText, isNotEmpty);

        service.commit();
        expect(service.confirmedText, isEmpty);

        // Watermark preserved: the same frame list now contains no new frames,
        // so process should return null instead of re-encoding committed audio.
        final result = await service.process([_dummyFrame, _dummyFrame]);
        expect(result, isNull);
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

  group('StreamingTranscriptionService pipeline stage error wrapping', () {
    test('wraps encode failures as PipelineStageException with stage "encode"',
        () async {
      final cause = StateError('onnx encoder failed');
      final service = StreamingTranscriptionService(
        encode: (_) async => throw cause,
        decoder: const DecoderService(blankId: 0),
        textService: const StubTokenIdToTextService(),
      );

      final result = service.process([_dummyFrame]);
      await expectLater(
        result,
        throwsA(
          isA<PipelineStageException>()
              .having((e) => e.stage, 'stage', 'encode')
              .having((e) => e.cause, 'cause', same(cause)),
        ),
      );
    });

    test('wraps decode failures as PipelineStageException with stage "decode"',
        () async {
      // encode returns logProbs whose length doesn't match the shape,
      // causing DecoderService to throw during beam search.
      final service = StreamingTranscriptionService(
        encode: (_) async => (
          List<double>.filled(10, 0.0),
          [1, 2, 3], // expects 6 values, not 10
          null,
        ),
        decoder: const DecoderService(blankId: 0),
        textService: const StubTokenIdToTextService(),
      );

      await expectLater(
        service.process([_dummyFrame]),
        throwsA(
          isA<PipelineStageException>()
              .having((e) => e.stage, 'stage', 'decode'),
        ),
      );
    });

    test(
        'wraps tokenise failures as PipelineStageException with stage "tokenise"',
        () async {
      final service = StreamingTranscriptionService(
        encode: _fakeEncode,
        decoder: const DecoderService(blankId: 0),
        textService: _ThrowingTextService(),
      );

      await expectLater(
        service.process([_dummyFrame]),
        throwsA(
          isA<PipelineStageException>()
              .having((e) => e.stage, 'stage', 'tokenise'),
        ),
      );
    });
  });
}

class _ThrowingTextService implements TokenIdToTextService {
  @override
  Future<DecodeResult> decode(Int32List tokenIds) async =>
      throw StateError('tokenise failed');
}
