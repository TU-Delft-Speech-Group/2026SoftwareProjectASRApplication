import 'dart:typed_data';

import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Vocab: 0 = blank, 1 = 'a', 2 = 'b', 3 = 'c'. Three frames with a peak each.
  const vocab = 4;
  List<double> frame(int peak) {
    final f = List<double>.filled(vocab, -10.0);
    f[peak] = 0.0;
    return f;
  }

  final logProbs = <double>[
    ...frame(1), // a
    ...frame(0), // blank
    ...frame(2), // b
  ];
  const shape = [3, vocab];

  const service = DecoderService(blankId: 0);

  test('greedy collapses blanks and repeats', () {
    final ids = service.decode(
      logProbs,
      shape: shape,
      mode: CtcDecodingMode.greedy,
    );
    expect(ids, [1, 2]);
  });

  test('prefix beam matches the obvious greedy path', () {
    final ids = service.decode(
      logProbs,
      shape: shape,
      mode: CtcDecodingMode.prefixBeam,
    );
    expect(ids, [1, 2]);
  });

  test('suppressedTokenIds drop tokens from the prefix beam', () {
    const filtered = DecoderService(blankId: 0, suppressedTokenIds: {2});
    final ids = filtered.decode(
      logProbs,
      shape: shape,
      mode: CtcDecodingMode.prefixBeam,
    );
    expect(ids, [1]);
  });

  test('joint ctc + transformer threads prefixes and caches per hypothesis',
      () async {
    final runner = _FakeRunner([1, 2, /* eos */ 3]);
    final jointService = const DecoderService(blankId: 0, eosId: 3);

    final ids = await jointService.decodeJoint(
      logProbs,
      shape: shape,
      runner: runner,
      beamSize: 1,
      tokenPruneSize: 4,
    );

    expect(ids, [1, 2]);

    // step 0: prefix = [sos], cache empty
    expect(runner.calls.first.prefix, [3]);
    expect(runner.calls.first.cacheLengths, List.filled(2, 0));
    // step 1: prefix = [sos, 1], cache grew by 1
    expect(runner.calls[1].prefix, [3, 1]);
    expect(runner.calls[1].cacheLengths, List.filled(2, 1));
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

class _FakeRunner implements TransformerDecoderRunner {
  final List<int> picks;
  final List<_Call> calls = [];
  int callIdx = 0;

  _FakeRunner(this.picks);

  @override
  int get vocab => 4;

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
