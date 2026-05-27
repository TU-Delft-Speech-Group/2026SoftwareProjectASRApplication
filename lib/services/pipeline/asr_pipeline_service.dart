import 'package:asr_application/services/audio/utterance_mvn.dart';
import 'package:asr_application/services/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/decoder/espnet_decoder_service.dart';
import 'package:asr_application/services/decoder/transformer_decoder_runner.dart';
import 'package:asr_application/services/encoder/espnet_encoder_service.dart';
import 'package:flutter/foundation.dart';

/// Glues the encoder, CTC, and optional transformer decoder services into a
/// single callable matching the [EncodeBuffer] contract expected by
/// [StreamingTranscriptionService].
class AsrPipelineService {
  AsrPipelineService({
    required EspnetEncoderService encoder,
    required EspnetCtcService ctc,
    UtteranceMvn normalizer = const UtteranceMvn(),
    this.maxFrames = _defaultMaxFrames,
    EspnetDecoderService? decoder,
  }) : _encoder = encoder,
       _ctc = ctc,
       _normalizer = normalizer,
       _decoder = decoder;

  // Gigaspeech encoder pos-enc overflows around 2090 mel frames (~21s of
  // audio). Must be >= StreamingTranscriptionService.maxBufferFrames so the
  // streaming buffer never grows into the encoder sliding-window range and
  // causes hypothesis instability at sentence ends.
  static const int _defaultMaxFrames = 1500;

  final EspnetEncoderService _encoder;
  final EspnetCtcService _ctc;
  final UtteranceMvn _normalizer;
  final EspnetDecoderService? _decoder;
  final int maxFrames;

  bool get isInitialized => _encoder.isInitialized && _ctc.isInitialized;

  Future<void> initialize() async {
    final decoder = _decoder;
    final futures = [
      _encoder.initialize(),
      _ctc.initialize(),
      if (decoder != null) decoder.initialize(),
    ];
    await Future.wait(futures);
  }

  Future<(List<double>, List<int>, TransformerDecoderRunner?)> encode(
    List<Float32List> frames,
  ) async {
    final windowed = frames.length > maxFrames
        ? frames.sublist(frames.length - maxFrames)
        : frames;
    // debugPrint(
    //   'AsrPipeline.encode: ${frames.length} frame(s) in, '
    //   'encoding last ${windowed.length}',
    // );
    final normalized = _normalizer.apply(windowed);
    final buffer = EncoderFrameBuffer.fromFrames(normalized);
    final encoded = await _encoder.encode(buffer);
    final ctc = await _ctc.computeTokenProbabilities(encoded);
    // debugPrint(
    //   'AsrPipeline.encode: CTC shape=${ctc.shape}, '
    //   'first values=${ctc.values.take(5).toList()}',
    // );
    final decoder = _decoder;
    final runner = decoder != null ? await decoder.makeRunner(encoded) : null;
    return (ctc.values, ctc.shape, runner);
  }

  Future<void> dispose() async {
    final decoder = _decoder;
    await Future.wait([
      _encoder.dispose(),
      _ctc.dispose(),
      if (decoder != null) decoder.dispose(),
    ]);
  }
}
