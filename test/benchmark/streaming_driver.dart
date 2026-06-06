import 'dart:typed_data';

import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';

import '../test_helpers.dart';

// Streams [wavPath] through [windowing] + [streaming] the way the live recorder
// would, and returns the assembled transcript. Mirrors RecordingCoordinator
// without the silence/pause heuristics: a benchmark drives every available
// frame through the pipeline rather than skip during silence.
Future<String> transcribeWav({
  required String wavPath,
  required StreamingTranscriptionService streaming,
  required WindowingService windowing,
  Duration chunkDuration = const Duration(milliseconds: 100),
  int sampleRate = 16000,
}) async {
  final pcm = await wavToPcm16(wavPath);
  final samples = _pcm16ToFloats(pcm);
  final chunkSamples = sampleRate * chunkDuration.inMilliseconds ~/ 1000;

  final assembler = TranscriptAssembler();
  final melFrames = <Float32List>[];

  for (var offset = 0; offset < samples.length; offset += chunkSamples) {
    final end = (offset + chunkSamples).clamp(0, samples.length);
    final chunk = samples.sublist(offset, end);
    final isLast = end >= samples.length;
    final windows = windowing.addSamples(chunk, flush: isLast);
    if (windows.isEmpty && !isLast) continue;
    for (final w in windows) {
      melFrames.add(Float32List.fromList(w.melEnergies));
    }
    final result = await streaming.process(melFrames);
    assembler.consume(result);
  }

  return assembler.finalize(fallback: streaming.confirmedText);
}

List<double> _pcm16ToFloats(Uint8List pcm) {
  final view = ByteData.sublistView(pcm);
  final usable = pcm.length - (pcm.length.isOdd ? 1 : 0);
  final out = List<double>.filled(usable ~/ 2, 0);
  for (var i = 0; i < out.length; i++) {
    out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

// Folds the stream of StreamResults into a final transcript.
//
// Each SegmentResult closes a segment and contributes its committed text. The
// final segment never sees a SegmentResult when audio ends mid-segment, so
// [finalize] takes a fallback (typically streaming.confirmedText).
//
// Factored out as a separate class so it can be unit-tested with a fake
// encoder, the same pattern the existing streaming tests use.
class TranscriptAssembler {
  final List<String> _committed = [];
  String _lastHypothesis = '';
  String _lastConfirmed = '';

  void consume(StreamResult? result) {
    if (result == null) return;
    _lastHypothesis = result.hypothesis;
    if (result.confirmedText.length > _lastConfirmed.length) {
      _lastConfirmed = result.confirmedText;
    }
    if (result is SegmentResult) {
      _committed.add(result.confirmedText);
      _lastHypothesis = '';
      _lastConfirmed = '';
    }
  }

  // Joined committed segments plus the best remaining text. "Best remaining"
  // prefers the last hypothesis when it cleanly extends the last confirmed
  // prefix (mirrors _bestCommitText in recording_coordinator.dart). Falls back
  // to [fallback] (typically the streaming service's confirmedText) when
  // neither is available.
  String finalize({required String fallback}) {
    final tail = _bestTail(fallback: fallback);
    final parts = [..._committed, if (tail.isNotEmpty) tail];
    return parts.join(' ').trim();
  }

  String _bestTail({required String fallback}) {
    if (_lastHypothesis.startsWith(_lastConfirmed) &&
        _lastHypothesis.length > _lastConfirmed.length) {
      return _lastHypothesis;
    }
    if (_lastConfirmed.isNotEmpty) return _lastConfirmed;
    return fallback;
  }
}
