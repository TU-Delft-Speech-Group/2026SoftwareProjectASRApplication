import 'dart:typed_data';

import 'package:asr_application/services/audio/silence_detector.dart';
import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';

import '../test_helpers.dart';

// Streams [wavPath] through [windowing] + [streaming] the way the live
// recorder would, and returns the assembled transcript. While
// [liveSilenceHandling] is on (the default), silent ticks before the first
// observed speech advance the streaming watermark via skipTo (mirroring
// RecordingCoordinator._skipUntilSpeech). After the first speech tick,
// every chunk is processed.
Future<String> transcribeWav({
  required String wavPath,
  required StreamingTranscriptionService streaming,
  required WindowingService windowing,
  Duration chunkDuration = const Duration(milliseconds: 100),
  int sampleRate = 16000,
  double silencePeak = SilenceDetector.thresholdPeak,
  Duration silenceSliceDuration = SilenceDetector.chunkDuration,
  bool liveSilenceHandling = true,
  // Diagnostic only: feeds the full audio through streaming.process in a
  // single call. Bypasses chunking and local agreement; sets the upper bound
  // for the ONNX layer.
  bool oneShot = false,
}) async {
  final pcm = await wavToPcm16(wavPath);
  final samples = _pcm16ToFloats(pcm);

  final assembler = TranscriptAssembler();
  final melFrames = <Float32List>[];

  if (oneShot) {
    final windows = windowing.addSamples(samples, flush: true);
    for (final w in windows) {
      melFrames.add(Float32List.fromList(w.melEnergies));
    }
    final result = await streaming.process(melFrames);
    assembler.consume(result);
    return assembler.finalize(fallback: streaming.confirmedText);
  }

  final sliceSamples =
      sampleRate * silenceSliceDuration.inMilliseconds ~/ 1000;
  final chunkSamples = sampleRate * chunkDuration.inMilliseconds ~/ 1000;
  final pending = <double>[];

  var waitingForSpeech = liveSilenceHandling;
  // Any slice in the current tick contained speech. Live looks at "most
  // recent chunk was silent"; pre-recorded WAVs can have speech bursts that
  // don't align to tick boundaries, so we widen the check to the whole tick.
  var chunkHadSpeech = false;

  for (var offset = 0; offset < samples.length; offset += sliceSamples) {
    final end = (offset + sliceSamples).clamp(0, samples.length);
    final slice = samples.sublist(offset, end);
    final isLast = end >= samples.length;

    if (liveSilenceHandling) {
      var peak = 0.0;
      for (final v in slice) {
        final abs = v < 0 ? -v : v;
        if (abs > peak) peak = abs;
      }
      if (peak >= silencePeak) chunkHadSpeech = true;
    }

    pending.addAll(slice);
    if (pending.length < chunkSamples && !isLast) continue;

    final windows = windowing.addSamples(pending, flush: isLast);
    pending.clear();
    if (windows.isEmpty && !isLast) continue;
    for (final w in windows) {
      melFrames.add(Float32List.fromList(w.melEnergies));
    }

    if (liveSilenceHandling && waitingForSpeech && !chunkHadSpeech) {
      streaming.skipTo(melFrames.length);
      chunkHadSpeech = false;
      continue;
    }
    waitingForSpeech = false;
    chunkHadSpeech = false;

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

  // Joined committed segments plus the best remaining text. The tail picks
  // the last hypothesis when it extends the locked prefix; otherwise the
  // locked prefix; otherwise [fallback]. Consecutive duplicate words are
  // collapsed because chunk boundaries occasionally confirm the same word
  // twice across ticks.
  String finalize({required String fallback}) {
    final tail = _bestTail(fallback: fallback);
    final parts = [..._committed, if (tail.isNotEmpty) tail];
    return _collapseDuplicates(parts.join(' ').trim());
  }

  static String _collapseDuplicates(String text) {
    if (text.isEmpty) return text;
    final words = text.split(' ');
    final out = <String>[];
    for (final w in words) {
      if (out.isEmpty || out.last.toLowerCase() != w.toLowerCase()) {
        out.add(w);
      }
    }
    return out.join(' ');
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
