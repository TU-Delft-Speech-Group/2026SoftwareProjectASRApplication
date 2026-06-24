import 'dart:developer' as dev;

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
  int _decoderOutputSize = 0;

  bool get isInitialized => _session != null;

  Future<void> initialize() async {
    if (_session != null) return;
    final runtime = OnnxRuntime();
    final filePath = _config.modelFilePath;
    final session = filePath != null
        ? await runtime.createSession(filePath, options: _config.sessionOptions)
        : await runtime.createSessionFromAsset(
            _config.modelAssetPath!,
            options: _config.sessionOptions,
          );
    // Input layout: [tgt, encoder_out, cache_0 … cache_{n-1}]
    _numLayers = session.inputNames.length - 2;
    _decoderOutputSize = await _resolveDecoderOutputSize(session);
    _session = session;
    dev.log('initialized: ${_config.modelAssetPath}', name: 'EspnetDecoder');
  }

  /// The decoder cache hidden size is the static last axis of the `cache_*`
  /// inputs (shape `[batch, length, size]`; axes 0 and 1 are dynamic). Reading
  /// it from the model means the empty-cache shape matches whatever recipe was
  /// exported — e.g. a 256-wide Dutch decoder vs. a 512-wide English one —
  /// instead of trusting a hardcoded config value. Falls back to the configured
  /// size if the runtime does not report a usable shape.
  Future<int> _resolveDecoderOutputSize(OrtSession session) async {
    if (session.inputNames.length < 3) return _config.decoderOutputSize;
    final firstCacheName = session.inputNames[2];
    try {
      final info = await session.getInputInfo();
      final cacheInfo = info.firstWhere(
        (e) => e['name'] == firstCacheName,
        orElse: () => const <String, dynamic>{},
      );
      final shape = cacheInfo['shape'];
      if (shape is List && shape.length >= 3) {
        final size = shape[2];
        if (size is int && size > 0) return size;
      }
    } catch (_) {
      // Fall through to the configured value below.
    }
    return _config.decoderOutputSize;
  }

  Future<OrtTransformerDecoderRunner> makeRunner(
    EncoderOutput encoderOutput,
  ) async {
    final session = _session;
    if (session == null) {
      throw StateError('EspnetDecoderService must be initialized first.');
    }
    dev.log(
      'makeRunner: encoderOut shape=${encoderOutput.shape}',
      name: 'EspnetDecoder',
    );
    final encoderOut = await OrtValue.fromList(
      encoderOutput.values,
      encoderOutput.shape,
    );
    // The decoder self-attention cache width equals the decoder attention dim,
    // which in an ESPnet conformer joint model is the encoder output hidden
    // size. Deriving it from the encoder_out tensor here is correct for any
    // model and avoids relying on a config fallback or on getInputInfo() shapes
    // (which the iOS onnxruntime plugin does not report, unlike macOS/Windows).
    final cacheWidth = encoderOutput.shape.isNotEmpty
        ? encoderOutput.shape.last
        : _decoderOutputSize;
    return OrtTransformerDecoderRunner(
      session: session,
      encoderOut: encoderOut,
      vocab: _config.vocab,
      numLayers: _numLayers,
      decoderOutputSize: cacheWidth,
    );
  }

  Future<void> dispose() async {
    final session = _session;
    _session = null;
    await session?.close();
  }
}
