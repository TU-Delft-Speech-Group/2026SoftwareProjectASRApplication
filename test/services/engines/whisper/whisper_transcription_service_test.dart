import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_mel_service.dart';
import 'package:asr_application/services/engines/whisper/whisper_tokenizer.dart';
import 'package:asr_application/services/engines/whisper/whisper_transcription_service.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';
import 'package:asr_application/services/shared/onnx/onnx_inference_contracts.dart';

const _sr = 16000;

// Word -> token id. 'Ġ' is the byte-level BPE marker for a leading space.
const _words = ['hello', 'there', 'friend', 'where', 'next', 'part'];
int _id(String w) => _words.indexOf(w);

class _NoBackend implements OnnxInferenceBackendContract {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Returns one scripted sentence per decode and never touches ONNX.
class _ScriptedPipeline extends WhisperAsrPipeline {
  _ScriptedPipeline(this.script)
      : super(encoderPath: 'e', decoderPath: 'd', backend: _NoBackend());
  final List<String> script;
  int calls = 0;

  @override
  Future<List<int>> greedyDecode({
    required Float32List melFeatures,
    required List<int> forcedTokens,
    int maxTokens = 224,
    int eosToken = 50257,
  }) async {
    final text = script[calls++];
    return [for (final w in text.split(' ')) _id(w), eosToken];
  }
}

/// Records how many samples each decode received.
class _RecordingMel extends WhisperMelService {
  final lengths = <int>[];
  @override
  Float32List compute(Float64List audio) {
    lengths.add(audio.length);
    return Float32List(1);
  }
}

Future<WhisperTokenizer> _tokenizer() async {
  final dir = await Directory.systemTemp.createTemp('wtok');
  final f = File('${dir.path}/tokenizer.json');
  await f.writeAsString(jsonEncode({
    'model': {
      'vocab': {for (final w in _words) '\u0120$w': _id(w)},
    },
  }));
  return WhisperTokenizer.load(f.path);
}

/// [seconds] of loud audio, optionally with a silent stretch.
Float32List _audio(double seconds, {double? quietAt}) {
  final n = (seconds * _sr).round();
  final a = Float32List(n);
  for (int i = 0; i < n; i++) {
    final t = i / _sr;
    final quiet = quietAt != null && t >= quietAt && t < quietAt + 0.1;
    a[i] = quiet ? 0.0 : (i.isEven ? 0.5 : -0.5);
  }
  return a;
}

void main() {
  late WhisperTokenizer tok;
  setUpAll(() async => tok = await _tokenizer());

  WhisperTranscriptionService service(_ScriptedPipeline p, _RecordingMel mel) =>
      WhisperTranscriptionService(
        pipeline: p,
        tokenizer: tok,
        language: 'nl',
        melService: mel,
      );

  test('waits for 1 s of audio, then decodes at most once per second', () async {
    final p = _ScriptedPipeline(['hello', 'hello there']);
    final s = service(p, _RecordingMel());

    expect(await s.process([_audio(0.5)]), isNull);
    expect(await s.process([_audio(1.0)]), isA<OngoingResult>());
    expect(await s.process([_audio(1.5)]), isNull); // < 1 s since last decode
    expect(await s.process([_audio(2.0)]), isA<OngoingResult>());
    expect(p.calls, 2);
  });

  test('confirms words two decodes agree on, and keeps them fixed', () async {
    final p = _ScriptedPipeline(['hello there', 'hello there friend', 'hello where next']);
    final s = service(p, _RecordingMel());

    final r1 = await s.process([_audio(1)]);
    expect(r1!.confirmedText, '');

    final r2 = await s.process([_audio(2)]);
    expect(r2!.confirmedText, 'hello there');
    expect(r2.hypothesis, 'hello there friend');

    // Later decode changes a confirmed word: confirmed text does not change,
    // and the display keeps it while following the new tail.
    final r3 = await s.process([_audio(3)]);
    expect(r3!.confirmedText, 'hello there');
    expect(r3.hypothesis, 'hello there next');
    expect(r3.hypothesis.startsWith(r3.confirmedText), isTrue);
  });

  test('after a pause commit the next segment only decodes new audio', () async {
    final p = _ScriptedPipeline(['hello', 'hello', 'next', 'next part']);
    final mel = _RecordingMel();
    final s = service(p, mel);

    await s.process([_audio(1)]);
    await s.process([_audio(2)]);
    expect(s.confirmedText, 'hello');

    // Coordinator: 5 s of silence, skipTo(live edge in frames), commit.
    s.skipTo((7 * _sr) ~/ 160);
    s.commit();
    expect(s.confirmedText, '');

    await s.process([_audio(8)]);
    expect(mel.lengths.last, 1 * _sr); // only the second after the pause
  });

  test('cap commit cuts at the quiet point and carries the rest over', () async {
    final p = _ScriptedPipeline([
      for (int i = 0; i < 9; i++) 'hello there',
      'hello there friend', // the cap decode
      'next',
    ]);
    final mel = _RecordingMel();
    final s = service(p, mel);

    for (int t = 1; t <= 9; t++) {
      expect(await s.process([_audio(t.toDouble(), quietAt: 9.2)]), isA<OngoingResult>());
    }
    final cap = await s.process([_audio(10.5, quietAt: 9.2)]);
    expect(cap, isA<SegmentResult>());
    expect(cap!.confirmedText, 'hello there friend');

    final cut = mel.lengths.last; // the cap decode covers [0, cut)
    expect(cut / _sr, inInclusiveRange(9.2, 9.3)); // inside the silent 100 ms

    await s.process([_audio(11.5, quietAt: 9.2)]);
    expect(mel.lengths.last, (11.5 * _sr).round() - cut); // starts at the cut
  });

  test('uses absolute positions when the recorder has dropped old samples', () async {
    final p = _ScriptedPipeline(['hello', 'there']);
    final mel = _RecordingMel();
    final s = service(p, mel);

    s.skipTo((40 * _sr) ~/ 160); // segment starts at 40 s
    s.setRawAudioOffset(35 * _sr); // buffer holds 35 s .. 42 s
    await s.process([_audio(7)]);
    expect(mel.lengths.last, 2 * _sr); // 40 s .. 42 s only
  });

  test('implements RawAudioOffsetAware so the coordinator reports offsets', () {
    final s = service(_ScriptedPipeline(const []), _RecordingMel());
    expect(s, isA<RawAudioOffsetAware>());
    expect(s.needsRawAudio, isTrue);
  });
}
