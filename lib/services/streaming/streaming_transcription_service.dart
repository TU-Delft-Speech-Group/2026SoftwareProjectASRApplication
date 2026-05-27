import 'dart:typed_data';

import '../decoder/decoder_service.dart';
import '../token_decoder/token_id_to_text_service.dart';
import 'local_agreement_policy.dart';

export 'local_agreement_policy.dart';
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

/* snapshot returned after processing each audio chunk */
class StreamResult {
  const StreamResult({
    required this.confirmedText,
    required this.hypothesis,
    this.sentenceConfirmed = false,
  });

  // word boundary prefix confirmed by local agreement (n) across the last n chunks
  final String confirmedText;

  // full CTC hypothesis for the current buffer
  final String hypothesis;

  // true when the confirmed prefix is sentence-final and the buffer was reset
  final bool sentenceConfirmed;
}

/*
  handles streaming local agreement pipeline;
  it maintains the growing processing buffer internally and applies
  local agreement policy across consecutive hypotheses to confirm
  stable prefixes;
  - buffer reset: when a complete sentence is confirmed the buffer and
  history are cleared; _processedUpTo is preserved so only new frames
  are processed for the next sentence
*/
class StreamingTranscriptionService {
  StreamingTranscriptionService({
    required EncodeBuffer encode,
    required DecoderService decoder,
    required TokenIdToTextService textService,
    LocalAgreementPolicy policy = const LocalAgreementPolicy(),
    this.maxBufferFrames = _defaultMaxBufferFrames,
  }) : _encode = encode,
       _decoder = decoder,
       _textService = textService,
       _policy = policy;

  // ~15s of mel frames. Must be <= AsrPipelineService.maxFrames (1500) so the
  // forced commit happens before the encoder window starts sliding; sliding
  // causes hypothesis instability and final words get dropped from confirmation.
  static const int _defaultMaxBufferFrames = 1500;

  final EncodeBuffer _encode;
  final DecoderService _decoder;
  final TokenIdToTextService _textService;
  final LocalAgreementPolicy _policy;
  final int maxBufferFrames;

  final List<Float32List> _buffer = [];
  final List<String> _history = [];
  String _confirmedText = '';
  int _processedUpTo = 0;

  String get confirmedText => _confirmedText;
  int get bufferLength => _buffer.length;

  /* feeds allFrames, the full accumulated frame list from the recorder;
    only frames beyond the previous call's watermark are added to the buffer;
    returns null when there are no new frames to process
  */
  Future<StreamResult?> process(List<Float32List> allFrames) async {
    if (allFrames.length <= _processedUpTo) return null;

    final newFrames = allFrames.sublist(_processedUpTo);

    // Pre-encode commit: when adding the new frames would saturate the buffer
    // AND there is prior history, commit the last stable hypothesis before
    // re-encoding so the encoder's sliding window cannot destabilise it. The
    // new frames seed the next segment's buffer instead of being discarded.
    // When history is empty this is the segment's first decode, so no prior
    // context can drift; fall through and encode first.
    if (_buffer.length + newFrames.length >= maxBufferFrames &&
        _history.isNotEmpty) {
      final segmentText =
          _confirmedText.isNotEmpty ? _confirmedText : _history.last;
      _resetBuffer();
      _buffer.addAll(newFrames);
      _processedUpTo = allFrames.length;
      return StreamResult(
        confirmedText: segmentText,
        hypothesis: segmentText,
        sentenceConfirmed: true,
      );
    }

    _processedUpTo = allFrames.length;
    _buffer.addAll(newFrames);

    final (logProbs, shape, runner) = await _encode(_buffer);
    final Int32List tokenIds;
    try {
      tokenIds = runner != null
          ? await _decoder.decodeJoint(logProbs, shape: shape, runner: runner)
          : _decoder.decode(logProbs, shape: shape);
    } finally {
      await runner?.dispose();
    }
    final decoded = await _textService.decode(tokenIds);
    final hypothesis = decoded.text;

    _history.add(hypothesis);

    // Strip the already-confirmed prefix (by word count) before running local
    // agreement so confirmation can advance even when earlier words flicker.
    // e.g. confirmed="...I NEED THIS", hist[-1] has "NORMALLY" but hist[-2]
    // has "MORALLY" — the full-string common prefix stalls at "SPEAK", but the
    // suffix-based view still agrees on "UP TO TRANSCRIBE".
    final confirmedWordCount =
        _confirmedText.isEmpty ? 0 : _confirmedText.split(' ').length;
    final lookupHistory = confirmedWordCount == 0
        ? _history
        : _history.map((h) {
            final words = h.isEmpty ? <String>[] : h.split(' ');
            return words.length > confirmedWordCount
                ? words.sublist(confirmedWordCount).join(' ')
                : '';
          }).toList();
    final extension = _policy.confirmedPrefix(lookupHistory);
    if (extension != null && extension.isNotEmpty) {
      _confirmedText =
          _confirmedText.isEmpty ? extension : '$_confirmedText $extension';
    }
    if (_confirmedText.isNotEmpty && _isSentenceFinal(_confirmedText)) {
      final sentenceText = _confirmedText;
      _resetBuffer();
      return StreamResult(
        confirmedText: sentenceText,
        hypothesis: hypothesis,
        sentenceConfirmed: true,
      );
    }

    // Post-encode commit: buffer was already at capacity before the first decode
    // in this segment (history was empty, so we encoded first above).
    if (_buffer.length >= maxBufferFrames) {
      final segmentText =
          _confirmedText.isNotEmpty ? _confirmedText : hypothesis;
      _resetBuffer();
      return StreamResult(
        confirmedText: segmentText,
        hypothesis: hypothesis,
        sentenceConfirmed: true,
      );
    }

    return StreamResult(confirmedText: _confirmedText, hypothesis: hypothesis);
  }

  /* resets all state between recordings */
  void reset() {
    _buffer.clear();
    _history.clear();
    _confirmedText = '';
    _processedUpTo = 0;
  }

  /* advances the watermark to frameCount without adding frames to the buffer;
    callers (e.g. silence detection) use this to discard silence frames so they
    do not accumulate in the encoder buffer and destabilise the hypothesis
  */
  void skipTo(int frameCount) {
    if (frameCount > _processedUpTo) _processedUpTo = frameCount;
  }

  /* commits the current segment state without rewinding the watermark;
    callers (e.g. pause detection in the view model) use this to start a new
    segment within an ongoing recording without forcing the streaming service
    to re-encode audio that has already been processed
  */
  void commit() => _resetBuffer();

  /* discards buffered audio and transcript history for the next sentence;
    _processedUpTo is preserved such that old recorder frames
    are not passed again into the new buffer
  */
  void _resetBuffer() {
    _buffer.clear();
    _history.clear();
    _confirmedText = '';
  }

  static bool _isSentenceFinal(String text) {
    if (text.isEmpty) return false;
    return text.endsWith('.') || text.endsWith('?') || text.endsWith('!');
  }
}
