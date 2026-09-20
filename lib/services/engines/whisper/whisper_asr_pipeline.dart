import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';

/// Whisper encoder-decoder pipeline backed by ONNX Runtime.
///
/// Unlike the ESPnet pipeline (which exposes separate CTC + optional decoder
/// stages), Whisper is a single encoder-decoder: the encoder produces hidden
/// states and the decoder autoregressively generates token ids.
class WhisperAsrPipeline implements AsrPipeline {
  WhisperAsrPipeline({
    required this.encoderPath,
    required this.decoderPath,
  });

  final String encoderPath;
  final String decoderPath;

  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    // TODO: Load encoder and decoder ONNX sessions via OrtSessionOptions.
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    // TODO: Release ONNX sessions.
    _initialized = false;
  }
}
