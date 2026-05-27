import 'dart:typed_data';

import 'package:asr_application/services/decoder/joint_ctc_transformer_beam_search.dart';
import 'package:asr_application/services/decoder/transformer_decoder_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Vocab: 0 = blank, 1 = 'a', 2 = 'b', 3 = sos/eos.
  const vocab = 4;
  List<double> peak(int id) {
    final f = List<double>.filled(vocab, -10.0);
    f[id] = 0.0;
    return f;
  }

  test('threads a growing prefix and caches into the runner', () async {
    final runner = _ScriptedRunner(vocab: vocab, picks: [1, 2, 3]);
    final ids = await JointCtcTransformerBeamSearch(
      decoder: runner,
      ctcLogits: [...peak(1), ...peak(0), ...peak(2)],
      ctcShape: const [3, vocab],
      blankId: 0,
      sosId: 3,
      eosId: 3,
      beamSize: 1,
      tokenPruneSize: 4,
    ).decode();

    expect(ids, [1, 2]);
    expect(runner.calls.first.prefix, [3]);
    expect(runner.calls.first.cacheLengths, List.filled(2, 0));
    expect(runner.calls[1].prefix, [3, 1]);
    expect(runner.calls[1].cacheLengths, List.filled(2, 1));
  });

  test('forces an eos at maxlen when the runner never emits one', () async {
    final runner = _ScriptedRunner(vocab: vocab, picks: [1, 2]);
    final ids = await JointCtcTransformerBeamSearch(
      decoder: runner,
      ctcLogits: [...peak(1), ...peak(2)],
      ctcShape: const [2, vocab],
      blankId: 0,
      sosId: 3,
      eosId: 3,
      beamSize: 1,
      tokenPruneSize: 4,
    ).decode();

    expect(ids.length, lessThanOrEqualTo(2));
    expect(ids.contains(3), isFalse);
  });

  test('filters sos from candidates when sos differs from eos', () async {
    const wideVocab = 5;
    // 0 = blank, 1 = 'a', 2 = 'b', 3 = sos, 4 = eos.
    List<double> p(int id) {
      final f = List<double>.filled(wideVocab, -10.0);
      f[id] = 0.0;
      return f;
    }

    final runner = _ScriptedRunner(vocab: wideVocab, picks: [3, 1, 4]);
    final ids = await JointCtcTransformerBeamSearch(
      decoder: runner,
      ctcLogits: [...p(1), ...p(0), ...p(1)],
      ctcShape: const [3, wideVocab],
      blankId: 0,
      sosId: 3,
      eosId: 4,
      beamSize: 1,
      tokenPruneSize: 5,
    ).decode();

    expect(ids.contains(3), isFalse);
    expect(ids.contains(0), isFalse);
  });

  test('keeps multiple hypotheses alive with beamSize > 1', () async {
    final runner = _CallbackRunner(
      vocab: vocab,
      numLayers: 2,
      onStep: (prefix) {
        final lp = Float64List(vocab)..fillRange(0, vocab, -1000.0);
        if (prefix.length == 1) {
          lp[1] = -0.1;
          lp[2] = -0.2;
        } else {
          lp[3] = -0.01;
        }
        return lp;
      },
    );

    await JointCtcTransformerBeamSearch(
      decoder: runner,
      ctcLogits: [...peak(1), ...peak(2)],
      ctcShape: const [2, vocab],
      blankId: 0,
      sosId: 3,
      eosId: 3,
      beamSize: 2,
      tokenPruneSize: 4,
    ).decode();

    final secondStepPrefixes = runner.calls
        .skip(1)
        .map((c) => c.prefix.join(','))
        .toSet();
    expect(secondStepPrefixes, contains('3,1'));
    expect(secondStepPrefixes, contains('3,2'));
  });

  test('throws if the runner reports logProbs of unexpected length', () async {
    final runner = _CallbackRunner(
      vocab: vocab,
      numLayers: 2,
      onStep: (_) => Float64List(vocab + 1),
    );

    await expectLater(
      JointCtcTransformerBeamSearch(
        decoder: runner,
        ctcLogits: [...peak(1), ...peak(2)],
        ctcShape: const [2, vocab],
        blankId: 0,
        sosId: 3,
        eosId: 3,
        beamSize: 1,
        tokenPruneSize: 4,
      ).decode(),
      throwsStateError,
    );
  });

  test('throws if initialCaches disagrees with numLayers', () async {
    final runner = _BadInitialCachesRunner(vocab: vocab);

    await expectLater(
      JointCtcTransformerBeamSearch(
        decoder: runner,
        ctcLogits: [...peak(1), ...peak(2)],
        ctcShape: const [2, vocab],
        blankId: 0,
        sosId: 3,
        eosId: 3,
        beamSize: 1,
        tokenPruneSize: 4,
      ).decode(),
      throwsStateError,
    );
  });

  test('returns an empty sequence when ctc has a single frame', () async {
    final runner = _ScriptedRunner(vocab: vocab, picks: [3]);
    final ids = await JointCtcTransformerBeamSearch(
      decoder: runner,
      ctcLogits: peak(1),
      ctcShape: const [1, vocab],
      blankId: 0,
      sosId: 3,
      eosId: 3,
      beamSize: 1,
      tokenPruneSize: 4,
    ).decode();

    expect(ids, isEmpty);
  });
}

class _Call {
  final List<int> prefix;
  final List<int> cacheLengths;
  _Call(this.prefix, this.cacheLengths);
}

class _CountingCache {
  final int length;
  const _CountingCache(this.length);
}

class _BadInitialCachesRunner implements TransformerDecoderRunner {
  @override
  final int vocab;

  _BadInitialCachesRunner({required this.vocab});

  @override
  int get numLayers => 2;

  @override
  Future<List<Object>> initialCaches() async {
    return const [_CountingCache(0)];
  }

  @override
  Future<TransformerDecoderStep> step({
    required List<int> prefix,
    required List<Object> caches,
  }) async {
    return TransformerDecoderStep(
      logProbs: Float64List(vocab),
      caches: caches,
    );
  }

  @override
  Future<void> dispose() async {}
}

class _CallbackRunner implements TransformerDecoderRunner {
  @override
  final int vocab;
  @override
  final int numLayers;
  final Float64List Function(List<int> prefix) onStep;
  final List<_Call> calls = [];

  _CallbackRunner({
    required this.vocab,
    required this.numLayers,
    required this.onStep,
  });

  @override
  Future<List<Object>> initialCaches() async {
    return List<Object>.generate(numLayers, (_) => const _CountingCache(0));
  }

  @override
  Future<TransformerDecoderStep> step({
    required List<int> prefix,
    required List<Object> caches,
  }) async {
    final lens = caches
        .map((c) => (c as _CountingCache).length)
        .toList(growable: false);
    calls.add(_Call(List<int>.from(prefix), lens));

    final next = <Object>[
      for (final c in caches)
        _CountingCache((c as _CountingCache).length + 1),
    ];
    return TransformerDecoderStep(logProbs: onStep(prefix), caches: next);
  }

  @override
  Future<void> dispose() async {}
}

class _ScriptedRunner implements TransformerDecoderRunner {
  @override
  final int vocab;
  final List<int> picks;
  final List<_Call> calls = [];
  int callIdx = 0;

  _ScriptedRunner({required this.vocab, required this.picks});

  @override
  int get numLayers => 2;

  @override
  Future<List<Object>> initialCaches() async {
    return List<Object>.generate(numLayers, (_) => const _CountingCache(0));
  }

  @override
  Future<TransformerDecoderStep> step({
    required List<int> prefix,
    required List<Object> caches,
  }) async {
    final lens = caches
        .map((c) => (c as _CountingCache).length)
        .toList(growable: false);
    calls.add(_Call(List<int>.from(prefix), lens));

    final lp = Float64List(vocab)..fillRange(0, vocab, -1000.0);
    final pick = picks[callIdx.clamp(0, picks.length - 1)];
    callIdx++;
    lp[pick] = -0.01;

    final next = <Object>[
      for (final c in caches)
        _CountingCache((c as _CountingCache).length + 1),
    ];
    return TransformerDecoderStep(logProbs: lp, caches: next);
  }

  @override
  Future<void> dispose() async {}
}
