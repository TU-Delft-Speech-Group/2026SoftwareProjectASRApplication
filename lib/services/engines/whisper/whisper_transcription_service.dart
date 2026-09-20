import 'dart:typed_data';
import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_tokenizer.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';

/// Streaming transcription service for Whisper models.
///
/// Strategy: accumulates audio frames and periodically runs the full
/// encoder-decoder pipeline on the buffered audio. This is the simplest
/// approach and works well for whisper-tiny on mobile hardware.
class WhisperTranscriptionService implements AsrTranscriptionService {
  WhisperTranscriptionService({
    required this.pipeline,
    required this.tokenizer,
    required this.language,
  });

  final WhisperAsrPipeline pipeline;
  final WhisperTokenizer tokenizer;
  final String language;

  final List<Float32List> _frameBuffer = [];
  String _confirmedText = '';
  int _processedFrames = 0;

  @override
  String get confirmedText => _confirmedText;

  @override
  Future<StreamResult?> process(List<Float32List> allFrames) async {
    // Buffer new frames beyond what we've already seen.
    if (allFrames.length > _processedFrames) {
      _frameBuffer.addAll(allFrames.sublist(_processedFrames));
      _processedFrames = allFrames.length;
    }

    // TODO: When enough frames have accumulated (~1-2s of audio):
    // 1. Convert frames to mel spectrogram
    // 2. Run encoder
    // 3. Run autoregressive decoder
    // 4. Decode tokens to text
    // For now return null (no result yet).
    return null;
  }

  @override
  void commit() {
    // Finalize current segment.
    _frameBuffer.clear();
    _processedFrames = 0;
  }

  @override
  void reset() {
    _frameBuffer.clear();
    _confirmedText = '';
    _processedFrames = 0;
  }

  @override
  void skipTo(int frameCount) {
    // Discard frames up to frameCount.
    _processedFrames = frameCount;
  }
}
