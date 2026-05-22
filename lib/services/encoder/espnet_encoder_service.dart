import 'package:asr_application/model/shared/encoder_frame_buffer.dart';
import 'package:asr_application/model/shared/encoder_output.dart';
import 'package:asr_application/services/shared/onnx/onnx.dart';
import 'package:flutter/foundation.dart';

import 'espnet_encoder_config.dart';

export 'package:asr_application/model/shared/encoder_frame_buffer.dart';
export 'package:asr_application/model/shared/encoder_output.dart';
export 'package:asr_application/services/shared/onnx/onnx.dart';

export 'espnet_encoder_config.dart';

// ESPnet exported encoder models expect input names and return output names
// They are currently hardcoded in this service
const _featsInputName = 'feats';
const _encoderOutputName = 'encoder_out';
const _encoderLengthOutputName = 'encoder_out_lens';

/// Runs the encoder part of an ESPnet ASR model exported to ONNX
class EspnetEncoderService {
  EspnetEncoderService({
    required EspnetEncoderConfig config,
    OnnxInferenceBackendContract? backend,
  }) : _config = config,
       _backend = backend ?? OnnxInferenceBackend();

  final EspnetEncoderConfig _config;
  final OnnxInferenceBackendContract _backend;

  OnnxInferenceSessionContract? _session;

  bool get isInitialized => _session != null;

  Future<void> initialize() async {
    if (_session != null) {
      return;
    }

    _session = await _backend.createSessionFromAsset(
      _config.modelAssetPath,
      options: _config.sessionOptions,
    );
  }

  Future<EncoderOutput> encode(EncoderFrameBuffer frames) async {
    final session = _session;
    if (session == null) {
      throw StateError('EspnetEncoderService must be initialized first.');
    }

    final feats = await _backend.createTensor(frames.values, frames.shape);

    Map<String, OnnxTensorContract> outputs;
    try {
      outputs = await session.run({_featsInputName: feats});
    } finally {
      await _safeDisposeAll([feats]);
    }

    try {
      final encoderOutput = outputs[_encoderOutputName];
      if (encoderOutput == null) {
        throw StateError(
          'Encoder ONNX session did not return $_encoderOutputName.',
        );
      }

      final values = await encoderOutput.asFloat32List();
      final encodedFrameCount = await _readEncodedFrameCount(outputs);

      return EncoderOutput(
        values: values,
        shape: encoderOutput.shape,
        encodedFrameCount: encodedFrameCount,
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

  Future<int?> _readEncodedFrameCount(
    Map<String, OnnxTensorContract> outputs,
  ) async {
    final lengthOutput = outputs[_encoderLengthOutputName];
    if (lengthOutput == null) {
      return null;
    }

    final values = await lengthOutput.asList();
    if (values.isEmpty) {
      return null;
    }

    final first = values.first;
    if (first is num) {
      return first.toInt();
    }

    throw StateError(
      'Encoder length output $_encoderLengthOutputName did not contain '
      'numeric values.',
    );
  }

  Future<void> _safeDisposeAll(Iterable<OnnxTensorContract> tensors) async {
    for (final tensor in tensors) {
      try {
        await tensor.dispose();
      } catch (error) {
        debugPrint('Error disposing encoder tensor: $error');
      }
    }
  }
}
