import 'package:asr_application/services/audio/utterance_mvn.dart';
import 'package:asr_application/services/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/encoder/espnet_encoder_service.dart';
import 'package:flutter/foundation.dart';

/// Glues the encoder and CTC services into a single callable matching the
/// [EncodeBuffer] contract expected by [StreamingTranscriptionService].
class AsrPipelineService {
  AsrPipelineService({
    required EspnetEncoderService encoder,
    required EspnetCtcService ctc,
    UtteranceMvn normalizer = const UtteranceMvn(),
    this.maxFrames = _defaultMaxFrames,
  }) : _encoder = encoder,
       _ctc = ctc,
       _normalizer = normalizer;

  // Gigaspeech encoder pos-enc overflows around 2090 mel frames (~21s of
  // audio). Keep a generous safety margin.
  static const int _defaultMaxFrames = 1800;

  final EspnetEncoderService _encoder;
  final EspnetCtcService _ctc;
  final UtteranceMvn _normalizer;
  final int maxFrames;

  bool get isInitialized => _encoder.isInitialized && _ctc.isInitialized;

  Future<void> initialize() async {
    await Future.wait([_encoder.initialize(), _ctc.initialize()]);
  }

  Future<(List<double>, List<int>)> encode(List<Float32List> frames) async {
    final windowed = frames.length > maxFrames
        ? frames.sublist(frames.length - maxFrames)
        : frames;
    debugPrint(
      'AsrPipeline.encode: ${frames.length} frame(s) in, '
      'encoding last ${windowed.length}',
    );
    final normalized = _normalizer.apply(windowed);
    final buffer = EncoderFrameBuffer.fromFrames(normalized);
    final encoded = await _encoder.encode(buffer);
    final ctc = await _ctc.computeTokenProbabilities(encoded);
    debugPrint(
      'AsrPipeline.encode: CTC shape=${ctc.shape}, '
      'first values=${ctc.values.take(5).toList()}',
    );
    return (ctc.values, ctc.shape);
  }

  Future<void> dispose() async {
    await Future.wait([_encoder.dispose(), _ctc.dispose()]);
  }
}
