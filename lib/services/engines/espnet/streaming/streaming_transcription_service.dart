import 'dart:developer' as dev;
import 'dart:typed_data';

import '../../../../exceptions/pipeline/pipeline_stage_exception.dart';
import '../decoder/decoder_service.dart';
import '../../../pipeline/asr_transcription_service.dart';
import '../../../token_decoder/token_id_to_text_service.dart';
import '../../../streaming/local_agreement_policy.dart';

export '../../../pipeline/asr_transcription_service.dart'
    show OngoingResult, SegmentResult, StreamResult;
export '../../../streaming/local_agreement_policy.dart';
export '../decoder/transformer_decoder_runner.dart'
    show TransformerDecoderRunner;

/*
  callback that encodes a list of audio feature frames to CTC log-probability
  logits, their shape, and an optional per-call transformer decoder runner for
  joint CTC+attention decoding; the runner must be disposed by the callee after
  decoding (its encoderOut OrtValue is live for exactly one decode call);
  frames is the full accumulated processing buffer;
  each Float32List is one feature frame;
*/
typedef EncodeBuffer =
    Future<(List<double>, List<int>, TransformerDecoderRunner?)> Function(
      List<Float32List> frames,
    );

/*
  handles streaming local agreement pipeline;
  maintains the growing per-segment frame buffer internally and applies
  local agreement policy across consecutive hypotheses to confirm stable
  prefixes; buffer resets on segment boundaries while the processed-frames
  watermark is preserved so old frames are not re-encoded
*/
class StreamingTranscriptionService implements AsrTranscriptionService {
  StreamingTranscriptionService({
    required EncodeBuffer encode,
    required DecoderService decoder,
    required TokenIdToTextService textService,
    LocalAgreementPolicy? policy,
    this.maxBufferFrames = _defaultMaxBufferFrames,
    int minEncodeFrames = _defaultMinEncodeFrames,
  }) : _encode = encode,
       _decoder = decoder,
       _textService = textService,
       _minEncodeFrames = minEncodeFrames,
       _policy = policy ?? LocalAgreementPolicy() {
    if (maxBufferFrames < 1) {
      throw ArgumentError(
        'maxBufferFrames must be >= 1 (got $maxBufferFrames).',
      );
    }
  }

  // ~15s of mel frames. Must be <= EspnetAsrPipeline.maxFrames (1500) so the
  // forced commit happens before the encoder window starts sliding; sliding
  // causes hypothesis instability and final words get dropped from confirmation.
  static const int _defaultMaxBufferFrames = 1500;

  // Minimum buffered mel frames before invoking the encoder. The conformer's
  // conv2d subsampling front-end needs a minimum sequence length to produce a
  // valid output (factor-8 subsampling needs 15); a sparse VAD-gated tick can
  // otherwise deliver one or two frames and crash the conv node on a {1,80}
  // input. Frames below this are held in the buffer until enough accumulate.
  // Normal 500ms ticks deliver ~50 frames, so this only affects pathologically
  // small ticks. Tests with a fake encoder that accepts any length pass 1.
  static const int _defaultMinEncodeFrames = 16;

  final EncodeBuffer _encode;
  final DecoderService _decoder;
  final TokenIdToTextService _textService;
  final LocalAgreementPolicy _policy;
  final int maxBufferFrames;
  final int _minEncodeFrames;

  final List<Float32List> _buffer = [];
  final List<String> _history = [];
  String _confirmedText = '';
  int _processedUpTo = 0;

  @override
  bool get needsRawAudio => false;

  @override
  String get confirmedText => _confirmedText;
  int get bufferLength => _buffer.length;

  @override
  Future<StreamResult?> process(List<Float32List> allFrames) async {
    if (allFrames.length <= _processedUpTo) return null;
    final newFrames = allFrames.sublist(_processedUpTo);

    final earlyCommit = _tryPreEncodeCommit(newFrames);
    if (earlyCommit != null) {
      _processedUpTo = allFrames.length;
      return earlyCommit;
    }

    _buffer.addAll(newFrames);
    _processedUpTo = allFrames.length;

    // Not enough frames for the encoder's conv subsampling yet; keep them
    // buffered and wait for the next tick rather than crashing the conv node.
    if (_buffer.length < _minEncodeFrames) return null;

    final hypothesis = await _encodeAndDecode();
    _appendHistory(hypothesis);
    _tryAdvanceConfirmedText();

    return _finalizeOrContinue(hypothesis);
  }

  /* resets all state between recordings */
  @override
  void reset() {
    _buffer.clear();
    _history.clear();
    _confirmedText = '';
    _processedUpTo = 0;
  }

  /* commits the current segment without rewinding the watermark; used by the
    viewmodel at pause boundaries to start a new segment mid-recording */
  @override
  void commit() => _resetSegment();

  /* advances the watermark without buffering frames; used after a pause commit
    to discard trailing silence so the next segment starts with actual speech */
  @override
  void skipTo(int frameCount) {
    if (frameCount > _processedUpTo) _processedUpTo = frameCount;
  }

  // Pre-encode commit: when the buffer is full AND there is prior history,
  // commit before encoding to prevent the encoder's sliding window from
  // destabilising a hypothesis that was stable on the previous tick.
  // When history is empty this is the segment's first decode — no prior
  // context can drift, so fall through and encode first.
  // newFrames are seeded into the next segment so they are not dropped.
  SegmentResult? _tryPreEncodeCommit(List<Float32List> newFrames) {
    if (_buffer.length + newFrames.length < maxBufferFrames ||
        _history.isEmpty) {
      return null;
    }
    final text = _confirmedText.isNotEmpty ? _confirmedText : _history.last;
    dev.log(
      'pre-encode commit: buffer=${_buffer.length} frames, text="$text"',
      name: 'StreamingTranscription',
    );
    _resetSegment();
    _buffer.addAll(newFrames);
    return SegmentResult(confirmedText: text, hypothesis: text);
  }

  StreamResult _finalizeOrContinue(String hypothesis) {
    if (_confirmedText.isNotEmpty && _isSentenceFinal(_confirmedText)) {
      final text = _confirmedText;
      dev.log(
        'sentence-final commit: text="$text"',
        name: 'StreamingTranscription',
      );
      _resetSegment();
      return SegmentResult(confirmedText: text, hypothesis: hypothesis);
    }

    // Post-encode commit: buffer was already at capacity before the first decode
    // in this segment (history was empty above, so we encoded first).
    if (_buffer.length >= maxBufferFrames) {
      final text = _confirmedText.isNotEmpty ? _confirmedText : hypothesis;
      dev.log(
        'post-encode commit: buffer=${_buffer.length} frames, text="$text"',
        name: 'StreamingTranscription',
      );
      _resetSegment();
      return SegmentResult(confirmedText: text, hypothesis: hypothesis);
    }

    return OngoingResult(confirmedText: _confirmedText, hypothesis: hypothesis);
  }

  void _resetSegment() {
    _buffer.clear();
    _history.clear();
    _confirmedText = '';
  }

  Future<String> _encodeAndDecode() async {
    List<double> logProbs;
    List<int> shape;
    TransformerDecoderRunner? runner;
    try {
      (logProbs, shape, runner) = await _encode(_buffer);
    } catch (e, st) {
      Error.throwWithStackTrace(
        PipelineStageException(stage: 'encode', cause: e, stackTrace: st),
        st,
      );
    }

    final Int32List tokenIds;
    try {
      tokenIds = runner != null
          ? await _decoder.decodeJoint(logProbs, shape: shape, runner: runner)
          : _decoder.decode(logProbs, shape: shape);
    } catch (e, st) {
      Error.throwWithStackTrace(
        PipelineStageException(stage: 'decode', cause: e, stackTrace: st),
        st,
      );
    } finally {
      await runner?.dispose();
    }

    try {
      return (await _textService.decode(tokenIds)).text;
    } catch (e, st) {
      Error.throwWithStackTrace(
        PipelineStageException(stage: 'tokenise', cause: e, stackTrace: st),
        st,
      );
    }
  }

  void _appendHistory(String hypothesis) {
    _history.add(hypothesis);
    if (_history.length > _policy.n) _history.removeAt(0);
  }

  // Strip the already-confirmed prefix (by word count) before running local
  // agreement so confirmation can advance even when earlier words flicker.
  // e.g. hist[-2]="MORALLY I NEED THIS" and hist[-1]="NORMALLY I NEED THIS" —
  // the full-string common prefix stalls at "", but the suffix view (skipping
  // the first confirmed word) still agrees on "I NEED THIS".
  void _tryAdvanceConfirmedText() {
    final extension = _policy.confirmedPrefix(_suffixHistory());
    if (extension == null || extension.isEmpty) return;
    _confirmedText = _confirmedText.isEmpty
        ? extension
        : '$_confirmedText $extension';
  }

  List<String> _suffixHistory() {
    if (_confirmedText.isEmpty) return _history;
    final confirmedWordCount = _confirmedText.split(' ').length;
    return _history.map((h) {
      final words = h.isEmpty ? <String>[] : h.split(' ');
      return words.length > confirmedWordCount
          ? words.sublist(confirmedWordCount).join(' ')
          : '';
    }).toList();
  }

  static bool _isSentenceFinal(String text) =>
      text.endsWith('.') || text.endsWith('?') || text.endsWith('!');
}
