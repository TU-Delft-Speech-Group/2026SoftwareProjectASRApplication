import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

abstract class OnnxInferenceBackendContract {
  Future<OnnxInferenceSessionContract> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  });

  Future<OnnxInferenceSessionContract> createSessionFromFile(
    String filePath, {
    OrtSessionOptions? options,
  });

  Future<OnnxTensorContract> createTensor(dynamic data, List<int> shape);
}

abstract class OnnxInferenceSessionContract {
  Future<Map<String, OnnxTensorContract>> run(
    Map<String, OnnxTensorContract> inputs,
  );

  Future<void> close();
}

abstract class OnnxTensorContract {
  List<int> get shape;

  Future<Float32List> asFloat32List();

  Future<List<dynamic>> asList();

  Future<void> dispose();
}

/// Result of one fused Whisper KV decoder step.
class WhisperStepResult {
  const WhisperStepResult({
    required this.logits,
    required this.selfK,
    required this.selfV,
  });

  /// [V] logits, or null when they were not requested.
  final Float32List? logits;

  /// New self-attention cache. The old cache tensors have been released.
  final OnnxTensorContract selfK;
  final OnnxTensorContract selfV;
}

/// Optional backend capability: one Whisper KV decoder step in a single call
/// (token and position inputs, run, logits, cache swap). Backends without it
/// keep working; the pipeline then uses the generic per-tensor calls.
abstract class WhisperDecoderStepContract {
  /// Returns null when the platform does not support the fused step; the
  /// caller then falls back to the generic path with its tensors untouched.
  Future<WhisperStepResult?> whisperDecoderStep({
    required OnnxInferenceSessionContract session,
    required int token,
    required int pos,
    required OnnxTensorContract selfK,
    required OnnxTensorContract selfV,
    required OnnxTensorContract crossK,
    required OnnxTensorContract crossV,
    required bool wantLogits,
  });
}
