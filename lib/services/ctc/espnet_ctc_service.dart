import 'package:asr_application/model/shared/ctc_output.dart';
import 'package:asr_application/model/shared/encoder_output.dart';
import 'package:asr_application/services/shared/onnx/onnx.dart';
import 'package:flutter/foundation.dart';

import 'espnet_ctc_config.dart';

export 'package:asr_application/model/shared/ctc_output.dart';
export 'package:asr_application/model/shared/encoder_output.dart';
export 'package:asr_application/services/shared/onnx/onnx.dart';

export 'espnet_ctc_config.dart';

const _encoderHiddenInputName = 'x';
const _ctcOutputName = 'ctc_out';

/// Runs the CTC part of an ESPnet ASR model exported to ONNX.
///
/// The service accepts encoder output and returns raw CTC token logits or
/// probabilities for a later decoder step.
class EspnetCtcService {
  EspnetCtcService({
    required EspnetCtcConfig config,
    OnnxInferenceBackendContract? backend,
  }) : _config = config,
       _backend = backend ?? OnnxInferenceBackend();

  final EspnetCtcConfig _config;
  final OnnxInferenceBackendContract _backend;

  OnnxInferenceSessionContract? _session;

  bool get isInitialized => _session != null;

  Future<void> initialize() async {
    if (_session != null) {
      return;
    }

    final filePath = _config.modelFilePath;
    _session = filePath != null
        ? await _backend.createSessionFromFile(
            filePath,
            options: _config.sessionOptions,
          )
        : await _backend.createSessionFromAsset(
            _config.modelAssetPath!,
            options: _config.sessionOptions,
          );
  }

  Future<CtcOutput> computeTokenProbabilities(
    EncoderOutput encoderOutput,
  ) async {
    final session = _session;
    if (session == null) {
      throw StateError('EspnetCtcService must be initialized first.');
    }

    final encoderTensor = await _backend.createTensor(
      encoderOutput.values,
      encoderOutput.shape,
    );

    Map<String, OnnxTensorContract> outputs;
    try {
      outputs = await session.run({_encoderHiddenInputName: encoderTensor});
    } finally {
      await _safeDispose(encoderTensor);
    }

    try {
      final ctcOutput = outputs[_ctcOutputName];
      if (ctcOutput == null) {
        throw StateError('CTC ONNX session did not return $_ctcOutputName.');
      }

      return CtcOutput(
        values: await ctcOutput.asFloat32List(),
        shape: ctcOutput.shape,
      );
    } finally {
      await _safeDisposeAll(outputs.values);
    }
  }

  Future<void> dispose() async {
    final session = _session;
    _session = null;
    await session?.close();
  }

  Future<void> _safeDispose(OnnxTensorContract tensor) async {
    try {
      await tensor.dispose();
    } catch (error) {
      debugPrint('Error disposing CTC tensor: $error');
    }
  }

  Future<void> _safeDisposeAll(Iterable<OnnxTensorContract> tensors) async {
    for (final tensor in tensors) {
      await _safeDispose(tensor);
    }
  }
}
