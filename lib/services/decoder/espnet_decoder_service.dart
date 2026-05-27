import 'package:asr_application/model/shared/encoder_output.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'espnet_decoder_config.dart';
import 'ort_transformer_decoder_runner.dart';

export 'espnet_decoder_config.dart';

/// Loads the transformer decoder ONNX session and creates per-call
/// [OrtTransformerDecoderRunner] instances for joint CTC+attention decoding.
///
/// One runner is created per [makeRunner] call, wrapping the encoder output
/// from that specific forward pass. The caller is responsible for calling
/// [OrtTransformerDecoderRunner.dispose] once decoding is complete.
class EspnetDecoderService {
  EspnetDecoderService({required EspnetDecoderConfig config})
      : _config = config;

  final EspnetDecoderConfig _config;
  OrtSession? _session;
  int _numLayers = 0;

  bool get isInitialized => _session != null;

  Future<void> initialize() async {
    if (_session != null) return;
    final runtime = OnnxRuntime();
    final session = await runtime.createSessionFromAsset(
      _config.modelAssetPath,
      options: _config.sessionOptions,
    );
    // Input layout: [tgt, encoder_out, cache_0 … cache_{n-1}]
    _numLayers = session.inputNames.length - 2;
    _session = session;
  }

  Future<OrtTransformerDecoderRunner> makeRunner(
    EncoderOutput encoderOutput,
  ) async {
    final session = _session;
    if (session == null) {
      throw StateError('EspnetDecoderService must be initialized first.');
    }
    final encoderOut = await OrtValue.fromList(
      encoderOutput.values,
      encoderOutput.shape,
    );
    return OrtTransformerDecoderRunner(
      session: session,
      encoderOut: encoderOut,
      vocab: _config.vocab,
      numLayers: _numLayers,
      decoderOutputSize: _config.decoderOutputSize,
    );
  }

  Future<void> dispose() async {
    final session = _session;
    _session = null;
    await session?.close();
  }
}
