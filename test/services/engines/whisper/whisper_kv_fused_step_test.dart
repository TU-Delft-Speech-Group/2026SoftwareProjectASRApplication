import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' show OrtSessionOptions;
import 'package:flutter_test/flutter_test.dart';

import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/shared/onnx/onnx.dart';

const _eos = 7;

class _T implements OnnxTensorContract {
  _T(this.shape, [List<num>? values]) : values = values ?? const [];
  @override
  final List<int> shape;
  final List<num> values;
  bool disposed = false;
  @override
  Future<Float32List> asFloat32List() async =>
      Float32List.fromList(values.map((v) => v.toDouble()).toList());
  @override
  Future<List<dynamic>> asList() async => values;
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _S implements OnnxInferenceSessionContract {
  _S(this.onRun);
  final Map<String, OnnxTensorContract> Function(Map<String, OnnxTensorContract>) onRun;
  int runs = 0;
  @override
  Future<Map<String, OnnxTensorContract>> run(
    Map<String, OnnxTensorContract> inputs,
  ) async {
    runs++;
    return onRun(inputs);
  }

  @override
  Future<void> close() async {}
}

// Deterministic fake decoder step: the best token depends on token and pos,
// EOS from position 12; the cache grows by one per step.
Map<String, OnnxTensorContract> _decoderStep(Map<String, OnnxTensorContract> i) {
  final token = (i['token']! as _T).values.first.toInt();
  final pos = (i['pos']! as _T).values.first.toInt();
  final s = i['self_k']!.shape;
  final best = pos >= 12 ? _eos : (token * 3 + pos) % _eos;
  final logits = List<num>.generate(10, (v) => v == best ? 1.0 : 0.0);
  final next = [s[0], s[1], s[2], s[3] + 1, s[4]];
  return {
    'logits': _T([1, 10], logits),
    'new_self_k': _T(next),
    'new_self_v': _T(next),
  };
}

class _Backend implements OnnxInferenceBackendContract, WhisperDecoderStepContract {
  _Backend({required this.fused});
  final bool fused;
  int createTensorCalls = 0;
  int fusedCalls = 0;
  final _S dec = _S(_decoderStep);
  final _S enc = _S((_) => {'last_hidden_state': _T([1, 1500, 8])});
  final _S xkv = _S(
    (_) => {'cross_k': _T([2, 1, 2, 1500, 4]), 'cross_v': _T([2, 1, 2, 1500, 4])},
  );

  @override
  Future<OnnxInferenceSessionContract> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  }) => createSessionFromFile(assetPath, options: options);

  @override
  Future<OnnxInferenceSessionContract> createSessionFromFile(
    String filePath, {
    OrtSessionOptions? options,
  }) async => switch (filePath) {
    'enc' => enc,
    'dec' => dec,
    'xkv' => xkv,
    _ => throw ArgumentError(filePath),
  };

  @override
  Future<OnnxTensorContract> createTensor(dynamic data, List<int> shape) async {
    createTensorCalls++;
    return _T(shape, (data as List).cast<num>());
  }

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
    if (!fused) return null; // like a platform without the method
    fusedCalls++;
    final out = await session.run({
      'token': _T([1, 1], [token]),
      'pos': _T([1], [pos]),
      'self_k': selfK,
      'self_v': selfV,
      'cross_k': crossK,
      'cross_v': crossV,
    });
    final logits = wantLogits ? await out['logits']!.asFloat32List() : null;
    await selfK.dispose();
    await selfV.dispose();
    return WhisperStepResult(
      logits: logits,
      selfK: out['new_self_k']!,
      selfV: out['new_self_v']!,
    );
  }
}

Future<List<int>> _decode(_Backend b) async {
  final p = WhisperKvAsrPipeline(
    encoderPath: 'enc',
    decoderStepPath: 'dec',
    crossKvPath: 'xkv',
    backend: b,
  );
  await p.initialize();
  return p.greedyDecode(
    melFeatures: Float32List(80 * 3000),
    forcedTokens: const [1, 2],
    maxTokens: 30,
    eosToken: _eos,
  );
}

void main() {
  test('fused decoder step gives exactly the same tokens as the generic path', () async {
    final generic = _Backend(fused: false);
    final fused = _Backend(fused: true);
    final a = await _decode(generic);
    final b = await _decode(fused);
    expect(b, a);
    expect(a.last, _eos);
    expect(fused.fusedCalls, generic.dec.runs); // one call per decoder step
    expect(fused.createTensorCalls, lessThan(generic.createTensorCalls));
  });

  test('falls back to the generic path when the fused step is unavailable', () async {
    final generic = _Backend(fused: false);
    final tokens = await _decode(generic);
    expect(generic.fusedCalls, 0);
    expect(generic.dec.runs, greaterThan(0));
    expect(tokens.last, _eos);
  });
}
