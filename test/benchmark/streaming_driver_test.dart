import 'dart:typed_data';

import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'package:asr_application/ui/home/view_models/recording_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'streaming_driver.dart';

class _FixedTextService implements TokenIdToTextService {
  const _FixedTextService(this._text);
  final String _text;
  @override
  Future<DecodeResult> decode(Int32List tokenIds) async =>
      DecodeResult(text: _text, tokenIds: tokenIds);
}

// Tiny CTC matrix: t=0 picks token 1, t=1 is blank, t=2 picks token 2. The
// text service returns a fixed string, so the actual token ids don't matter
// for transcript assembly.
Future<(List<double>, List<int>, TransformerDecoderRunner?)> _fakeEncode(
  List<Float32List> _,
) async => (
  const <double>[
    -100, 0, -100,
    0, -100, -100,
    -100, -100, 0,
  ],
  const <int>[3, 3],
  null,
);

void main() {
  group('EventTranscriptAssembler', () {
    test('finalize returns empty for no events', () {
      final a = EventTranscriptAssembler();
      expect(a.finalize(fallback: ''), '');
    });

    test('returns the pending hypothesis when nothing was committed', () {
      final a = EventTranscriptAssembler()
        ..consume(const HypothesisUpdated('hello world'));
      expect(a.finalize(fallback: ''), 'hello world');
    });

    test('joins committed segments with the pending tail', () {
      final a = EventTranscriptAssembler()
        ..consume(const SegmentCommitted('one sentence.'))
        ..consume(const HypothesisUpdated('and then more'));
      expect(a.finalize(fallback: ''), 'one sentence. and then more');
    });

    test('commit clears the pending hypothesis', () {
      final a = EventTranscriptAssembler()
        ..consume(const HypothesisUpdated('committed soon'))
        ..consume(const SegmentCommitted('committed soon.'));
      expect(a.finalize(fallback: ''), 'committed soon.');
    });

    test('uses the fallback when no event produced pending text', () {
      final a = EventTranscriptAssembler();
      expect(a.finalize(fallback: 'fallback only'), 'fallback only');
    });

    test('appends the fallback after a commit when nothing is pending', () {
      final a = EventTranscriptAssembler()
        ..consume(const SegmentCommitted('first segment.'));
      expect(
        a.finalize(fallback: 'trailing text'),
        'first segment. trailing text',
      );
    });

    test('ignores decoding lifecycle events', () {
      final a = EventTranscriptAssembler()
        ..consume(const DecodingStarted())
        ..consume(const HypothesisUpdated('words'))
        ..consume(const DecodingFinished());
      expect(a.finalize(fallback: ''), 'words');
    });

    test('collapses adjacent duplicate words across a segment join', () {
      final a = EventTranscriptAssembler()
        ..consume(const SegmentCommitted('the cat'))
        ..consume(const HypothesisUpdated('cat sat'));
      expect(a.finalize(fallback: ''), 'the cat sat');
    });

    test('adjacent dedup is case-insensitive', () {
      final a = EventTranscriptAssembler()
        ..consume(const HypothesisUpdated('Hope HOPE remains and remains strong'));
      expect(a.finalize(fallback: ''), 'Hope remains and remains strong');
    });

    test('rethrowFailure surfaces a RecordingFailed event', () {
      final a = EventTranscriptAssembler()
        ..consume(RecordingFailed(StateError('encoder exploded')));
      expect(a.rethrowFailure, throwsStateError);
    });

    test('rethrowFailure is a no-op without failures', () {
      final a = EventTranscriptAssembler()
        ..consume(const HypothesisUpdated('fine'));
      expect(a.rethrowFailure, returnsNormally);
    });
  });

  group('transcribeWav', () {
    test(
      'streams a real WAV through the production recording pipeline and '
      'returns the fixed text',
      () async {
        final streaming = StreamingTranscriptionService(
          encode: _fakeEncode,
          decoder: const DecoderService(blankId: 0),
          textService: const _FixedTextService('expected output'),
        );

        final transcript = await transcribeWav(
          wavPath: 'test/assets/poisoned_potato_test.wav',
          streaming: streaming,
        );

        // The fake encoder produces the same hypothesis for every tick, so
        // the coordinator emits HypothesisUpdated with the fixed text once
        // speech is detected; finalize returns that pending tail.
        expect(transcript, 'expected output');
      },
    );
  });
}
