import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_mel_service.dart';
import 'package:asr_application/services/engines/whisper/whisper_tokenizer.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';

/// Streaming transcription for Whisper on raw PCM.
///
/// Whisper has no streaming encoder, so each tick re-decodes the audio of the
/// current segment (from the segment start to the live edge, at most
/// [maxBufferSeconds]). Three rules turn that into stable captions:
///
/// * Local agreement: words on which two consecutive hypotheses agree become
///   confirmed and never change. The coordinator needs a non-empty confirmed
///   text before it commits a segment on a pause.
/// * Pause commit: the coordinator calls [skipTo] and [commit]; the next
///   segment starts after the pause, so committed audio is never decoded again.
/// * Cap commit: when a segment reaches [maxBufferSeconds], it is cut at the
///   quietest point near the end, that audio is decoded once more and returned
///   as a [SegmentResult], and the rest carries into the next segment. Long
///   speech without pauses is therefore not lost.
///
/// All positions are absolute sample indices since the recording started.
/// The recorder may drop old samples; [setRawAudioOffset] says where the
/// buffer passed to [process] starts.
class WhisperTranscriptionService
    implements AsrTranscriptionService, RawAudioOffsetAware {
  WhisperTranscriptionService({
    required this.pipeline,
    required this.tokenizer,
    required this.language,
    this.sampleRate = 16000,
    this.minInferenceSeconds = 1.0,
    this.maxBufferSeconds = 10.0,
    this.minSecondsBetweenInference = 1.0,
    this.cutSearchSeconds = 1.5,
    this.samplesPerFrame = 160,
    WhisperMelService? melService,
  }) : _melService = melService ?? WhisperMelService();

  final WhisperAsrPipeline pipeline;
  final WhisperTokenizer tokenizer;
  final String language;
  final int sampleRate;
  final double minInferenceSeconds;
  final double maxBufferSeconds;
  final double minSecondsBetweenInference;

  /// How far back from the cap to look for a quiet point to cut at.
  final double cutSearchSeconds;

  /// Hop of the recorder's windowing frames; converts [skipTo] frame counts
  /// to sample positions.
  final int samplesPerFrame;

  final WhisperMelService _melService;

  int get _minSamples => (sampleRate * minInferenceSeconds).round();
  int get _maxSamples => (sampleRate * maxBufferSeconds).round();
  int get _minStepSamples => (sampleRate * minSecondsBetweenInference).round();

  int _offset = 0; // absolute index of buffer[0]
  int _segStart = 0; // absolute start of the current segment
  int _lastInferenceEnd = 0; // absolute end of the audio last decoded
  List<String> _prevWords = const [];
  List<String> _confirmedWords = const [];
  bool _inferenceRunning = false;

  @override
  bool get needsRawAudio => true;

  @override
  String get confirmedText => _confirmedWords.join(' ');

  @override
  void setRawAudioOffset(int samples) => _offset = samples;

  @override
  Future<StreamResult?> process(List<Float32List> allFrames) async {
    if (allFrames.isEmpty || _inferenceRunning) return null;
    final pcm = allFrames[0];
    final total = _offset + pcm.length;
    if (_segStart < _offset) _segStart = _offset; // trimmed by the recorder

    if (total - _segStart < _minSamples) return null;
    if (total - _lastInferenceEnd < _minStepSamples) return null;

    _inferenceRunning = true;
    try {
      if (total - _segStart > _maxSamples) {
        final capEnd = _segStart + _maxSamples;
        final cut = _quietestPoint(
          pcm,
          from: max(_segStart + _minSamples,
              capEnd - (sampleRate * cutSearchSeconds).round()),
          to: capEnd,
        );
        final text = await _transcribe(pcm, _segStart, cut);
        debugPrint('WHISPER: cap commit at '
            '${((cut - _segStart) / sampleRate).toStringAsFixed(1)}s');
        _startSegment(cut);
        return SegmentResult(confirmedText: text, hypothesis: text);
      }

      final text = await _transcribe(pcm, _segStart, total);
      _lastInferenceEnd = total;
      final words = _split(text);

      // Local agreement over the last two hypotheses; confirmed only grows.
      final agreed = _commonPrefix(_prevWords, words);
      if (agreed > _confirmedWords.length &&
          _commonPrefix(_confirmedWords, words) == _confirmedWords.length) {
        _confirmedWords = words.sublist(0, agreed);
      }
      _prevWords = words;

      // Confirmed words stay fixed on screen; the rest follows the newest decode.
      final display = [
        ..._confirmedWords,
        ...words.skip(_confirmedWords.length),
      ].join(' ');
      return OngoingResult(confirmedText: confirmedText, hypothesis: display);
    } catch (e) {
      debugPrint('WHISPER ERROR: $e');
      return null;
    } finally {
      _inferenceRunning = false;
    }
  }

  /// Pause commit by the coordinator. [skipTo] has already moved past the
  /// pause, so the next segment starts with new audio.
  @override
  void commit() => _startSegment(max(_segStart, _lastInferenceEnd));

  @override
  void reset() {
    _offset = 0;
    _startSegment(0);
    _inferenceRunning = false;
  }

  /// Moves the segment start forward (never back); used to drop silence.
  @override
  void skipTo(int frameCount) {
    final s = frameCount * samplesPerFrame;
    if (s > _segStart) _segStart = s;
    if (s > _lastInferenceEnd) _lastInferenceEnd = s;
  }

  void _startSegment(int at) {
    _segStart = at;
    _lastInferenceEnd = at;
    _prevWords = const [];
    _confirmedWords = const [];
  }

  Future<String> _transcribe(Float32List pcm, int startAbs, int endAbs) async {
    final s = (startAbs - _offset).clamp(0, pcm.length);
    final e = (endAbs - _offset).clamp(s, pcm.length);
    final audio = Float64List(e - s);
    for (int i = 0; i < audio.length; i++) {
      audio[i] = pcm[s + i];
    }

    final watch = Stopwatch()..start();
    final mel = _melService.compute(audio);
    final melMs = watch.elapsedMilliseconds;
    final tokenIds = await pipeline.greedyDecode(
      melFeatures: mel,
      forcedTokens: tokenizer.forcedDecoderIds(language),
    );
    final text = tokenizer.decode(tokenIds);
    debugPrint('WHISPER: ${(audio.length / sampleRate).toStringAsFixed(1)}s audio | '
        'mel ${melMs}ms | total ${watch.elapsedMilliseconds}ms | "$text"');
    return text;
  }

  /// Absolute position of the centre of the lowest-energy 20 ms window in
  /// [from, to); falls back to [to] when the range is too short.
  int _quietestPoint(Float32List pcm, {required int from, required int to}) {
    const win = 320, hop = 160;
    final lo = (from - _offset).clamp(0, pcm.length);
    final hi = (to - _offset).clamp(0, pcm.length);
    int best = hi;
    double bestEnergy = double.infinity;
    for (int i = lo; i + win <= hi; i += hop) {
      double sum = 0;
      for (int j = i; j < i + win; j++) {
        sum += pcm[j] * pcm[j];
      }
      if (sum < bestEnergy) {
        bestEnergy = sum;
        best = i + win ~/ 2;
      }
    }
    return _offset + best;
  }

  static List<String> _split(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Number of leading words two hypotheses share, ignoring case and
  /// punctuation (Whisper often changes "testing," to "testing." between runs).
  static int _commonPrefix(List<String> a, List<String> b) {
    String key(String w) => w
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    final n = min(a.length, b.length);
    int i = 0;
    while (i < n && key(a[i]) == key(b[i])) {
      i++;
    }
    return i;
  }
}
