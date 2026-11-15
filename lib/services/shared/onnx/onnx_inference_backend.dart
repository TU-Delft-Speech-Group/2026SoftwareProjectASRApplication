import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'onnx_inference_contracts.dart';
import 'onnx_inference_session.dart';
import 'onnx_tensor.dart';

/// Shared ONNX Runtime adapter used by ASR services.
///
/// It owns the conversion from Dart values to `OrtValue`s and creates runtime
/// sessions from model assets.
class OnnxInferenceBackend
    implements OnnxInferenceBackendContract, WhisperDecoderStepContract {
  OnnxInferenceBackend({OnnxRuntime? runtime})
    : _runtime = runtime ?? OnnxRuntime();

  final OnnxRuntime _runtime;

  @override
  Future<OnnxInferenceSession> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  }) async {
    final session = await _runtime.createSessionFromAsset(
      assetPath,
      options: options,
    );
    return OnnxInferenceSession(session);
  }

  @override
  Future<OnnxInferenceSession> createSessionFromFile(
    String filePath, {
    OrtSessionOptions? options,
  }) async {
    final session = await _runtime.createSession(filePath, options: options);
    return OnnxInferenceSession(session);
  }

  @override
  Future<OnnxTensor> createTensor(dynamic data, List<int> shape) async {
    final value = await OrtValue.fromList(data, shape);
    return OnnxTensor(value);
  }
  // Same channel the plugin uses. whisperDecoderStep exists only in our
  // patched Android plugin (packages/flutter_onnxruntime, see DISC_PATCH.md).
  static const MethodChannel _ortChannel = MethodChannel('flutter_onnxruntime');
  bool _fusedStepUnsupported = false;

  @override
  Future<WhisperStepResult?> whisperDecoderStep({
    required OnnxInferenceSessionContract session,
    required int token,
    required int pos,
    required OnnxTensorContract selfK,
    required OnnxTensorContract selfV,
    required OnnxTensorContract crossK,
    required OnnxTensorContract crossV,
    required bool wantLogits,
  }) async {
    if (_fusedStepUnsupported) return null;
    if (session is! OnnxInferenceSession ||
        selfK is! OnnxTensor ||
        selfV is! OnnxTensor ||
        crossK is! OnnxTensor ||
        crossV is! OnnxTensor) {
      return null;
    }
    final Map<String, dynamic>? r;
    try {
      r = await _ortChannel.invokeMapMethod<String, dynamic>(
        'whisperDecoderStep',
        {
          'sessionId': session.sessionId,
          'token': token,
          'pos': pos,
          'selfK': selfK.value.id,
          'selfV': selfV.value.id,
          'crossK': crossK.value.id,
          'crossV': crossV.value.id,
          'wantLogits': wantLogits,
        },
      );
    } on MissingPluginException {
      // macOS, iOS, web: no fused step; use the generic path from now on.
      _fusedStepUnsupported = true;
      return null;
    }
    if (r == null) return null;
    final shape = List<int>.from(r['cacheShape'] as List);
    OnnxTensor wrap(String id) => OnnxTensor(
      OrtValue.fromMap({'valueId': id, 'dataType': 'float32', 'shape': shape}),
    );
    final raw = r['logits'];
    final Float32List? logits = raw == null
        ? null
        : raw is Float32List
        ? raw
        : Float32List.fromList(
            (raw as List).map((e) => (e as num).toDouble()).toList(),
          );
    return WhisperStepResult(
      logits: logits,
      selfK: wrap(r['selfK'] as String),
      selfV: wrap(r['selfV'] as String),
    );
  }
}
