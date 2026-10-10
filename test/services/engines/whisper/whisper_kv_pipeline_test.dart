import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/shared/onnx/onnx_inference_contracts.dart';

class _FakeTensor implements OnnxTensorContract {
  _FakeTensor(this.data, this.shape);
  final List<num> data;
  @override
  final List<int> shape;
  bool disposed = false;

  @override
  Future<Float32List> asFloat32List() async =>
      Float32List.fromList(data.map((e) => e.toDouble()).toList());

  @override
  Future<List<dynamic>> asList() async => data;

  @override
  Future<void> dispose() async => disposed = true;
}

const _vocab = 100;
const _eos = 99;
const _layers = 2, _heads = 3, _headDim = 4;

/// Fake ONNX sessions: encoder, cross_kv and a decoder_step that emits a
/// scripted token sequence and grows the cache by one slot per call.
class _FakeSession implements OnnxInferenceSessionContract {
  _FakeSession(this.kind, this.backend);
  final String kind;
  final _FakeBackend backend;
  bool closed = false;

  @override
  Future<Map<String, OnnxTensorContract>> run(Map<String, OnnxTensorContract> inputs) async {
    switch (kind) {
      case 'encoder':
        return {'last_hidden_state': backend.track(_FakeTensor([0], [1, 1500, 8]))};
      case 'cross':
        final shape = [_layers, 1, _heads, 1500, _headDim];
        return {
          'cross_k': backend.track(_FakeTensor([0], shape)),
          'cross_v': backend.track(_FakeTensor([0], shape)),
        };
      default: // decoder_step
        final token = (inputs['token'] as _FakeTensor).data.single.toInt();
        final pos = (inputs['pos'] as _FakeTensor).data.single.toInt();
        final selfK = inputs['self_k'] as _FakeTensor;
        expect(selfK.disposed, isFalse, reason: 'cache fed after dispose');
        backend.steps.add([token, pos, selfK.shape[3]]);
        final next = backend.script[backend.steps.length - 1];
        final logits = List<num>.filled(_vocab, 0)..[next] = 1;
        final grown = [...selfK.shape]..[3] = selfK.shape[3] + 1;
        return {
          'logits': backend.track(_FakeTensor(logits, [1, _vocab])),
          'new_self_k': backend.track(_FakeTensor([0], grown)),
          'new_self_v': backend.track(_FakeTensor([0], grown)),
        };
    }
  }

  @override
  Future<void> close() async => closed = true;
}

class _FakeBackend implements OnnxInferenceBackendContract {
  _FakeBackend(this.script);

  /// Token whose logit is highest after the n-th decoder_step call.
  final List<int> script;
  final steps = <List<int>>[]; // [token, pos, cache length]
  final tensors = <_FakeTensor>[];
  final sessions = <_FakeSession>[];

  _FakeTensor track(_FakeTensor t) {
    tensors.add(t);
    return t;
  }

  @override
  Future<OnnxInferenceSessionContract> createSessionFromAsset(String assetPath,
          {OrtSessionOptions? options}) =>
      throw UnimplementedError();

  @override
  Future<OnnxInferenceSessionContract> createSessionFromFile(String filePath,
      {OrtSessionOptions? options}) async {
    final kind = filePath.contains('cross')
        ? 'cross'
        : filePath.contains('encoder')
            ? 'encoder'
            : 'step';
    final s = _FakeSession(kind, this);
    sessions.add(s);
    return s;
  }

  @override
  Future<OnnxTensorContract> createTensor(dynamic data, List<int> shape) async =>
      track(_FakeTensor(List<num>.from(data as List), shape));
}

WhisperKvAsrPipeline _pipeline(_FakeBackend b) => WhisperKvAsrPipeline(
      encoderPath: 'encoder.onnx',
      decoderStepPath: 'decoder.onnx',
      crossKvPath: 'cross_kv.onnx',
      backend: b,
    );

void main() {
  const forced = [50, 51, 52, 53];

  test('feeds forced prefix then one token per step, with growing cache', () async {
    // after 4 forced steps the model predicts 10, then 11, then EOS
    final b = _FakeBackend([0, 0, 0, 10, 11, _eos]);
    final p = _pipeline(b);
    await p.initialize();
    expect(p.isInitialized, isTrue);

    final out = await p.greedyDecode(
        melFeatures: Float32List(80 * 3000), forcedTokens: forced, eosToken: _eos);

    expect(out, [10, 11, _eos]);
    expect(b.steps, [
      [50, 0, 1], [51, 1, 2], [52, 2, 3], [53, 3, 4], // forced prefix
      [10, 4, 5], [11, 5, 6], // generated, EOS is not fed back
    ]);
  });

  test('disposes every tensor it creates', () async {
    final b = _FakeBackend([0, 0, 0, 10, _eos]);
    final p = _pipeline(b);
    await p.initialize();
    await p.greedyDecode(melFeatures: Float32List(80 * 3000), forcedTokens: forced, eosToken: _eos);
    expect(b.tensors.where((t) => !t.disposed), isEmpty);
  });

  test('stops at maxTokens', () async {
    final b = _FakeBackend([0, 0, 0, ...List.generate(20, (i) => 20 + i)]);
    final p = _pipeline(b);
    await p.initialize();
    final out = await p.greedyDecode(
        melFeatures: Float32List(80 * 3000), forcedTokens: forced, maxTokens: 5, eosToken: _eos);
    expect(out, [20, 21, 22, 23, 24]);
  });

  test('dispose closes all three sessions', () async {
    final b = _FakeBackend([]);
    final p = _pipeline(b);
    await p.initialize();
    await p.dispose();
    expect(b.sessions.length, 3);
    expect(b.sessions.every((s) => s.closed), isTrue);
    expect(p.isInitialized, isFalse);
  });

  test('argmaxNoRepeatTrigram bans a repeated trigram', () {
    final logits = Float32List(10)
      ..[7] = 5
      ..[3] = 4;
    // seq ends with 5, 6 and "5 6 7" already occurred -> 7 is banned
    expect(WhisperAsrPipeline.argmaxNoRepeatTrigram(logits, [5, 6, 7, 5, 6]), 3);
    expect(WhisperAsrPipeline.argmaxNoRepeatTrigram(logits, [1, 2, 5, 6]), 7);
  });
}
