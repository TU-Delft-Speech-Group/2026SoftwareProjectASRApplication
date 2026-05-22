import 'dart:typed_data';

import '../decoder/decoder_service.dart';
import '../token_decoder/token_id_to_text_service.dart';
import 'local_agreement_policy.dart';

export 'local_agreement_policy.dart';

/*
  callback that encodes a list of audio feature frames to CTC log-probability
  logits and their shape;
  frames is the full accumulated processing buffer; 
  each Float32List is one feature frame;
*/
typedef EncodeBuffer = Future<(List<double>, List<int>)> Function(
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

  // ~15s of mel frames. Comfortably under the AsrPipelineService cap (1800)
  // and the encoder positional-encoding ceiling (~2090). Past this size the
  // Gigaspeech encoder starts mutating earlier words as more context arrives.
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

  /* feeds allFrames, the full accumulated frame list from the recorder;
    only frames beyond the previous call's watermark are added to the buffer;
    returns null when there are no new frames to process
  */
  Future<StreamResult?> process(List<Float32List> allFrames) async {
    if (allFrames.length <= _processedUpTo) return null;

    final newFrames = allFrames.sublist(_processedUpTo);
    _processedUpTo = allFrames.length;
    _buffer.addAll(newFrames);

    final (logProbs, shape) = await _encode(_buffer);
    final tokenIds = _decoder.decode(logProbs, shape: shape);
    final decoded = await _textService.decode(tokenIds);
    final hypothesis = decoded.text;

    _history.add(hypothesis);
    final confirmed = _policy.confirmedPrefix(_history);
    if (confirmed != null) {
      _confirmedText = confirmed;
      if (_isSentenceFinal(confirmed)) {
        final sentenceText = _confirmedText;
        _resetBuffer();
        return StreamResult(
          confirmedText: sentenceText,
          hypothesis: hypothesis,
          sentenceConfirmed: true,
        );
      }
    }

    if (_buffer.length >= maxBufferFrames) {
      final segmentText = _confirmedText.isNotEmpty ? _confirmedText : hypothesis;
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
