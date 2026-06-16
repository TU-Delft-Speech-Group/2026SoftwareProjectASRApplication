import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:asr_application/services/engines/espnet/audio/utterance_mvn.dart';
import 'package:asr_application/services/engines/espnet/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/espnet_decoder_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/transformer_decoder_runner.dart';
import 'package:asr_application/services/engines/espnet/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';

/// ESPnet encoder + CTC + optional transformer decoder pipeline.
///
/// The generic [AsrPipeline] contract only defines lifecycle methods. ESPnet's
/// streaming service also uses [encode], which returns CTC logits plus an
/// optional joint decoder runner for the current encoder output.
final class EspnetAsrPipeline implements AsrPipeline {
  EspnetAsrPipeline({
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

  @override
  bool get isInitialized =>
      _encoder.isInitialized &&
      _ctc.isInitialized &&
      (_decoder?.isInitialized ?? true);

  @override
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
    dev.log(
      'encode: ${frames.length} frames in, encoding last ${windowed.length}',
      name: 'EspnetAsrPipeline',
    );
    final normalized = _normalizer.apply(windowed);
    final buffer = EncoderFrameBuffer.fromFrames(normalized);
    final encoded = await _encoder.encode(buffer);
    dev.log(
      'encoder out: shape=${encoded.shape}, '
      'encodedFrameCount=${encoded.encodedFrameCount}',
      name: 'EspnetAsrPipeline',
    );
    final ctc = await _ctc.computeTokenProbabilities(encoded);
    dev.log('ctc out: shape=${ctc.shape}', name: 'EspnetAsrPipeline');
    final decoder = _decoder;
    final runner = decoder != null ? await decoder.makeRunner(encoded) : null;
    return (ctc.values, ctc.shape, runner);
  }

  @override
  Future<void> dispose() async {
    final decoder = _decoder;
    await Future.wait([
      _encoder.dispose(),
      _ctc.dispose(),
      if (decoder != null) decoder.dispose(),
    ]);
  }
}
