import 'dart:typed_data';

import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
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
  group('TranscriptAssembler', () {
    test('finalize returns empty for no inputs', () {
      final a = TranscriptAssembler();
      expect(a.finalize(fallback: ''), '');
    });

    test('returns the hypothesis when nothing was committed yet', () {
      final a = TranscriptAssembler()
        ..consume(const OngoingResult(
          confirmedText: '',
          hypothesis: 'hello world',
        ));
      expect(a.finalize(fallback: ''), 'hello world');
    });

    test('prefers a hypothesis that extends the locked prefix', () {
      final a = TranscriptAssembler()
        ..consume(const OngoingResult(
          confirmedText: 'hello',
          hypothesis: 'hello world today',
        ));
      expect(a.finalize(fallback: ''), 'hello world today');
    });

    test('falls back to the locked prefix on mid-word regression', () {
      final a = TranscriptAssembler()
        ..consume(const OngoingResult(
          confirmedText: 'hello world',
          hypothesis: 'hello wor',
        ));
      expect(a.finalize(fallback: ''), 'hello world');
    });

    test('joins committed segments with the live tail', () {
      final a = TranscriptAssembler()
        ..consume(const SegmentResult(
          confirmedText: 'one sentence.',
          hypothesis: 'one sentence.',
        ))
        ..consume(const OngoingResult(
          confirmedText: 'and then',
          hypothesis: 'and then more',
        ));
      expect(a.finalize(fallback: ''), 'one sentence. and then more');
    });

    test('resets per-segment state after a SegmentResult', () {
      final a = TranscriptAssembler()
        ..consume(const OngoingResult(
          confirmedText: 'committed',
          hypothesis: 'committed soon',
        ))
        ..consume(const SegmentResult(
          confirmedText: 'committed soon.',
          hypothesis: 'committed soon.',
        ));
      expect(a.finalize(fallback: ''), 'committed soon.');
    });

    test('uses the fallback only when no segment ever produced output', () {
      final a = TranscriptAssembler();
      expect(a.finalize(fallback: 'fallback only'), 'fallback only');
    });

    test('ignores null results from process()', () {
      final a = TranscriptAssembler()
        ..consume(null)
        ..consume(const OngoingResult(
          confirmedText: '',
          hypothesis: 'words',
        ))
        ..consume(null);
      expect(a.finalize(fallback: ''), 'words');
    });

    test('collapses adjacent duplicate words', () {
      final a = TranscriptAssembler()
        ..consume(const OngoingResult(
          confirmedText: '',
          hypothesis: 'the the cat sat',
        ));
      expect(a.finalize(fallback: ''), 'the cat sat');
    });

    test('adjacent dedup is case-insensitive', () {
      final a = TranscriptAssembler()
        ..consume(const OngoingResult(
          confirmedText: '',
          hypothesis: 'Hope HOPE remains and remains strong',
        ));
      expect(
        a.finalize(fallback: ''),
        'Hope remains and remains strong',
      );
    });
  });

  group('transcribeWav', () {
    test(
      'streams a real WAV through windowing + fake encoder and returns the '
      'fixed text',
      () async {
        final streaming = StreamingTranscriptionService(
          encode: _fakeEncode,
          decoder: const DecoderService(blankId: 0),
          textService: const _FixedTextService('expected output'),
        );

        final transcript = await transcribeWav(
          wavPath: 'test/assets/poisoned_potato_test.wav',
          streaming: streaming,
          windowing: WindowingService(),
        );

        // Fake encoder produces the same hypothesis for every chunk, so local
        // agreement confirms it within a few chunks. The WAV is short enough
        // that no segment boundary fires, so finalize returns the confirmed
        // prefix.
        expect(transcript, 'expected output');
      },
    );
  });
}
