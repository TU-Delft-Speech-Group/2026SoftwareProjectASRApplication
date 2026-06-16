import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/ui/home/view_models/recording_coordinator.dart';
import 'package:record/record.dart';

import '../test_helpers.dart';

// Streams [wavPath] through the production recording pipeline: the PCM bytes
// flow through the real RecorderService (alignment, silence detection,
// windowing) and the real RecordingCoordinator (skip-until-speech, segment
// commits, hypothesis locking). The transcript is assembled from the
// coordinator's RecordingEvents the same way HomeViewModel fills its
// transcription list, so the benchmark exercises exactly what a live session
// runs.
//
// [chunkDuration] mirrors the ~100ms chunks the record plugin delivers;
// [tickInterval] mirrors the coordinator's 500ms decode cadence. Both default
// to the live values.
Future<String> transcribeWav({
  required String wavPath,
  required StreamingTranscriptionService streaming,
  WindowingService? windowing,
  Duration chunkDuration = const Duration(milliseconds: 100),
  Duration tickInterval = RecordingCoordinator.defaultChunkInterval,
  int sampleRate = 16000,
  bool liveSilenceHandling = true,
  // Diagnostic only: feeds the full audio through streaming.process in a
  // single call. Bypasses chunking and local agreement; sets the upper bound
  // for the ONNX layer.
  bool oneShot = false,
}) async {
  final pcm = await wavToPcm16(wavPath);

  if (oneShot) {
    return _transcribeOneShot(pcm, streaming, windowing ?? WindowingService());
  }

  // 2 bytes per 16-bit sample.
  final chunkBytes = 2 * sampleRate * chunkDuration.inMilliseconds ~/ 1000;
  final recorder = _WavAudioRecorder(pcm, chunkBytes: chunkBytes);
  final recorderService = liveSilenceHandling
      ? RecorderService(recorder, windowingService: windowing)
      : _NoSilenceRecorderService(recorder, windowingService: windowing);
  final coordinator = RecordingCoordinator(
    recorder: recorderService,
    streaming: streaming,
    chunkInterval: null,
  );
  final assembler = EventTranscriptAssembler();
  final subscription = coordinator.events.listen(assembler.consume);

  final chunksPerTick = max(
    1,
    tickInterval.inMilliseconds ~/ chunkDuration.inMilliseconds,
  );

  try {
    await coordinator.start();
    while (recorder.hasMore) {
      for (var i = 0; i < chunksPerTick && recorder.hasMore; i++) {
        recorder.emitNextChunk();
      }
      // Let the recorder's stream listener run before the coordinator reads
      // the accumulated frames, like the event loop interleaves them live.
      await Future<void>.delayed(Duration.zero);
      await coordinator.tick();
    }
    final fallback = await coordinator.stop();
    assembler.rethrowFailure();
    return assembler.finalize(fallback: fallback);
  } finally {
    await subscription.cancel();
    coordinator.dispose();
  }
}

Future<String> _transcribeOneShot(
  Uint8List pcm,
  StreamingTranscriptionService streaming,
  WindowingService windowing,
) async {
  final samples = _pcm16ToFloats(pcm);
  final melFrames = <Float32List>[
    for (final w in windowing.addSamples(samples, flush: true))
      Float32List.fromList(w.melEnergies),
  ];
  final result = await streaming.process(melFrames);
  if (result == null) return streaming.confirmedText;
  if (result.hypothesis.startsWith(result.confirmedText) &&
      result.hypothesis.length > result.confirmedText.length) {
    return result.hypothesis;
  }
  return result.confirmedText.isNotEmpty
      ? result.confirmedText
      : streaming.confirmedText;
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

// AudioRecorder stand-in that replays pre-recorded PCM through the same
// stream interface the record plugin uses, so RecorderService runs its real
// chunk handling. The driver pulls chunks explicitly via [emitNextChunk] to
// stay in control of pacing.
class _WavAudioRecorder implements AudioRecorder {
  _WavAudioRecorder(this._pcm, {required int chunkBytes})
      : _chunkBytes = chunkBytes;

  final Uint8List _pcm;
  final int _chunkBytes;
  int _offset = 0;
  final _controller = StreamController<Uint8List>.broadcast();

  bool get hasMore => _offset < _pcm.length;

  void emitNextChunk() {
    final end = min(_offset + _chunkBytes, _pcm.length);
    _controller.add(Uint8List.sublistView(_pcm, _offset, end));
    _offset = end;
  }

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async =>
      _controller.stream;

  @override
  Future<String?> stop() async {
    if (!_controller.isClosed) await _controller.close();
    return null;
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
        '_WavAudioRecorder does not support ${invocation.memberName}',
      );
}

// Disables silence handling for A/B experiments (DISABLE_LIVE_SILENCE=1):
// the coordinator sees zero silence and processes every chunk.
class _NoSilenceRecorderService extends RecorderService {
  _NoSilenceRecorderService(super.recorder, {super.windowingService});

  @override
  int get silenceDurationMs => 0;

  @override
  bool takeSpeechSinceLastCheck() => true;
}

// Folds the coordinator's RecordingEvents into a final transcript, mirroring
// how HomeViewModel fills its transcription list: SegmentCommitted closes an
// entry, HypothesisUpdated updates the pending one, and the pending entry
// falls back to the text returned by RecordingCoordinator.stop().
class EventTranscriptAssembler {
  final List<String> _committed = [];
  String _pendingText = '';
  Object? _failure;

  void consume(RecordingEvent event) {
    switch (event) {
      case SegmentCommitted(:final text):
        _committed.add(text);
        _pendingText = '';
      case HypothesisUpdated(:final displayText):
        _pendingText = displayText;
      case RecordingFailed(:final error):
        _failure = error;
      case DecodingStarted():
      case DecodingFinished():
        break;
    }
  }

  // Surfaces a RecordingFailed event as a thrown error so a pipeline failure
  // fails the benchmark instead of scoring an empty transcript.
  void rethrowFailure() {
    final failure = _failure;
    if (failure != null) {
      throw StateError('Recording pipeline failed during benchmark: $failure');
    }
  }

  // Joined committed segments plus the pending tail (last hypothesis if any,
  // otherwise [fallback]). Consecutive duplicate words are collapsed because
  // joining segments occasionally repeats the word at the boundary.
  String finalize({required String fallback}) {
    final tail = _pendingText.isNotEmpty ? _pendingText : fallback;
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
}
