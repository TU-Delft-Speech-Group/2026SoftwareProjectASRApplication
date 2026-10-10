import 'dart:async';
import 'dart:typed_data';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';

/*
  Events emitted by [RecordingCoordinator] during an active recording session.
  Consumers update their own state in response; the coordinator holds no UI
  references and has no knowledge of the transcription list.
*/
sealed class RecordingEvent {
  const RecordingEvent();
}

// Emitted immediately before ONNX inference so the UI can show a loading state.
final class DecodingStarted extends RecordingEvent {
  const DecodingStarted();
}

// Emitted after ONNX inference completes (or is skipped), paired with
// DecodingStarted.
final class DecodingFinished extends RecordingEvent {
  const DecodingFinished();
}

// Emitted with new display text after each decode tick. The text is either the
// full current hypothesis (when it extends the confirmed prefix) or the locked
// prefix (when the hypothesis regressed mid-word).
final class HypothesisUpdated extends RecordingEvent {
  const HypothesisUpdated(this.displayText);
  final String displayText;
}

// Emitted when a segment boundary is reached (sentence-final punctuation,
// silence pause, or buffer cap). Consumers should commit the current
// transcription entry and open a new one.
final class SegmentCommitted extends RecordingEvent {
  const SegmentCommitted(this.text);
  final String text;
}

// Emitted when an unrecoverable error occurs during chunk processing;
// The session is stopped automatically before this event fires.
final class RecordingFailed extends RecordingEvent {
  const RecordingFailed(this.error);
  final Object error;
}

enum _Phase { waitingForSpeech, active }

/*
  Coordinates the recording lifecycle and per-tick chunk processing.
  Drives [RecorderService] and [AsrTranscriptionService] and surfaces
  results as a [RecordingEvent] stream so the ViewModel stays free of
  recording-specific state.

  Lifecycle: call [start] to begin a session and [stop] to end it.
  [dispose] must be called when the coordinator is no longer needed.
*/
class RecordingCoordinator {
  RecordingCoordinator({
    required RecorderService recorder,
    required AsrTranscriptionService streaming,
    Duration? chunkInterval = defaultChunkInterval,
    int silenceToleranceMs = 0,
    int preRollFrames = 0,
  }) : _recorder = recorder,
       _streaming = streaming,
       _chunkInterval = chunkInterval,
       _silenceToleranceMs = silenceToleranceMs,
       _preRollFrames = preRollFrames;

  static const Duration defaultChunkInterval = Duration(milliseconds: 500);

  // Tick cadence for live sessions. Null disables the internal timer so a
  // harness (the accuracy benchmark) can drive ticks itself via [tick] while
  // reusing the exact same per-tick processing as a live session.
  final Duration? _chunkInterval;

  // How many milliseconds of consecutive silence are tolerated before frames
  // are skipped. Default 0 skips on the first silent chunk.
  final int _silenceToleranceMs;

  // How many mel frames of pre-speech audio to retain when trimming leading
  // silence (1 frame = 10 ms). When silence is skipped the watermark is left
  // this many frames behind the live edge, so the soft onset that precedes
  // detection is encoded once speech fires instead of being discarded.
  // Default 0 reproduces the hard-trim behaviour.
  final int _preRollFrames;

  // Commit the current segment after this much continuous silence.
  static const int _pauseCommitMs = 5000;

  final RecorderService _recorder;
  final AsrTranscriptionService _streaming;

  // Synchronous broadcast so event handlers run inline during stop(),
  // guaranteeing the transcription list is up to date before the caller
  // finalizes the last entry.
  final StreamController<RecordingEvent> _events =
      StreamController<RecordingEvent>.broadcast(sync: true);

  Stream<RecordingEvent> get events => _events.stream;

  Timer? _chunkTimer;
  bool _isProcessingChunk = false;
  _Phase _phase = _Phase.waitingForSpeech;
  String _lockedText = '';
  String _lastHypothesis = '';

  Future<void> initialize() => _recorder.initialize();

  Future<void> start() async {
    _lockedText = '';
    _lastHypothesis = '';
    _phase = _Phase.waitingForSpeech;
    _streaming.reset();
    await _recorder.start();
    final interval = _chunkInterval;
    if (interval != null) {
      _chunkTimer = Timer.periodic(interval, (_) => _processChunk());
    }
  }

  /// Processes one chunk tick outside the internal timer. Only meaningful
  /// when the coordinator was constructed with `chunkInterval: null`.
  Future<void> tick() => _processChunk();

  // Stops the session and runs one final chunk to flush any buffered audio.
  // Returns [AsrTranscriptionService.confirmedText] as a fallback for
  // callers to finalize a transcription entry that never received committed text.
  Future<String> stop() async {
    _chunkTimer?.cancel();
    _chunkTimer = null;
    await _recorder.stop();
    await _processChunk();
    return _streaming.confirmedText;
  }

  void dispose() {
    _chunkTimer?.cancel();
    _events.close();
  }

  Future<void> _processChunk() async {
    if (_isProcessingChunk) return;
    _isProcessingChunk = true;

    try {
      final frames = _collectFrames();
      if (frames == null) return;

      if (_phase == _Phase.waitingForSpeech) {
        if (_skipUntilSpeech(frames)) return;
      }

      if (_commitOnSilence(frames)) return;

      await _processActiveChunk(frames);
    } finally {
      _isProcessingChunk = false;
    }
  }

  // Discards silence frames by advancing the watermark; returns true (skip
  // this tick) until speech is detected, then transitions to active.
  //
  // Checks whether speech occurred anywhere since the previous tick rather
  // than only in the most recent chunk, so an utterance that starts mid-tick
  // and dips at the tick boundary is not discarded (#211).
  bool _skipUntilSpeech(List<Float32List> frames) {
    final hadSpeech = _recorder.takeSpeechSinceLastCheck();
    if (!hadSpeech && _recorder.silenceDurationMs > _silenceToleranceMs) {
      // Leave _preRollFrames behind the live edge so the soft speech onset that
      // precedes detection is retained instead of trimmed. skipTo only advances,
      // so the watermark trails the live edge by the pre-roll once it catches up.
      final keepFrom = frames.length - _preRollFrames;
      _streaming.skipTo(keepFrom > 0 ? keepFrom : 0);
      return true;
    }
    _phase = _Phase.active;
    return false;
  }

  // Commits the current segment after sustained silence exceeds the threshold.
  // Returns true when a commit was performed so the caller skips active
  // processing for this tick.
  bool _commitOnSilence(List<Float32List> frames) {
    if (_recorder.silenceDurationMs < _pauseCommitMs || _lockedText.isEmpty) {
      return false;
    }
    _streaming.skipTo(frames.length);
    _emit(SegmentCommitted(_bestCommitText()));
    _resetSegmentState();
    _streaming.commit();
    return true;
  }

  // Returns the last hypothesis when it cleanly extends the locked prefix;
  // otherwise falls back to the locked prefix itself.
  String _bestCommitText() {
    if (_lastHypothesis.startsWith(_lockedText) &&
        _lastHypothesis.length > _lockedText.length) {
      return _lastHypothesis;
    }
    return _lockedText;
  }

  Future<void> _processActiveChunk(List<Float32List> frames) async {
    _emit(const DecodingStarted());
    try {
      final result = await _streaming.process(frames);
      _emit(const DecodingFinished());
      if (result == null) return;

      _lastHypothesis = result.hypothesis;
      if (result.confirmedText.length > _lockedText.length) {
        _lockedText = result.confirmedText;
      }

      switch (result) {
        case SegmentResult(:final confirmedText):
          final committed = confirmedText.length > _lockedText.length
              ? confirmedText
              : _lockedText;
          _emit(SegmentCommitted(committed));
          _resetSegmentState();
        case OngoingResult(:final hypothesis):
          _emit(HypothesisUpdated(_resolveDisplayText(hypothesis)));
      }
    } catch (error) {
      _emit(const DecodingFinished());
      _stopSession();
      _emit(RecordingFailed(error));
    }
  }

  void _stopSession() {
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _streaming.reset();
  }

  // Shows the full hypothesis when it still contains the locked prefix;
  // falls back to the locked prefix to avoid surfacing a mid-word regression.
  String _resolveDisplayText(String hypothesis) {
    if (hypothesis.startsWith(_lockedText)) return hypothesis;
    return _lockedText.isNotEmpty ? _lockedText : hypothesis;
  }

  void _resetSegmentState() {
    _lockedText = '';
    _lastHypothesis = '';
    _phase = _Phase.waitingForSpeech;
    // Discard speech observed during the segment that just closed, so the
    // next waiting-for-speech check only reacts to new audio.
    _recorder.takeSpeechSinceLastCheck();
  }

  List<Float32List>? _collectFrames() {
    final frames = _recorder.frames;
    if (frames.isEmpty) return null;
    if (_streaming.needsRawAudio) {
      // Pass raw continuous PCM as a single chunk per call.
      // This avoids the overlap distortion from windowed frames.
      final pcm = _recorder.rawPcm;
      if (pcm.isEmpty) return null;
      if (_streaming case final RawAudioOffsetAware aware) {
        aware.setRawAudioOffset(_recorder.rawPcmOffset);
      }
      return [Float32List.fromList(pcm)];
    }
    return frames.map((w) => Float32List.fromList(w.melEnergies)).toList();
  }

  void _emit(RecordingEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
