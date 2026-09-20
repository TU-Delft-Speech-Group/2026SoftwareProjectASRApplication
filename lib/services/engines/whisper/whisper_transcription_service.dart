import 'dart:typed_data';
import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_tokenizer.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';

/// Streaming transcription service for Whisper models.
///
/// Strategy: accumulates audio chunks and periodically runs the full
/// encoder-decoder pipeline on the buffered audio. This is the simplest
/// approach (no incremental decoding) and works well for whisper-tiny on
/// mobile hardware.
class WhisperTranscriptionService implements AsrTranscriptionService {
  WhisperTranscriptionService({
    required this.pipeline,
    required this.tokenizer,
    required this.language,
  });

  final WhisperAsrPipeline pipeline;
  final WhisperTokenizer tokenizer;
  final String language;

  final List<double> _audioBuffer = [];
  String _lastTranscript = '';

  @override
  String process(Float32List audioChunk) {
    _audioBuffer.addAll(audioChunk);
    // TODO: Run encoder + decoder on _audioBuffer when enough audio
    // has accumulated (e.g. every 1-2 seconds).
    return _lastTranscript;
  }

  @override
  String commit() {
    final result = _lastTranscript;
    _audioBuffer.clear();
    _lastTranscript = '';
    return result;
  }

  @override
  void reset() {
    _audioBuffer.clear();
    _lastTranscript = '';
  }
}
