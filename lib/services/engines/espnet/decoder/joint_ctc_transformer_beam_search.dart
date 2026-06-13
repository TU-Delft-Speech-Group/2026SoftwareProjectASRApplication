// Disclaimer: this file was drafted with AI assistance. I have read through
// every line, understand what it does, and have tested both the algorithm
// (against a Python reference) and the integration end-to-end.

import 'dart:math';
import 'dart:typed_data';

import 'ctc_logits.dart';
import 'transformer_decoder_runner.dart';

class JointCtcTransformerBeamSearch {
  final TransformerDecoderRunner decoder;
  final List<double> ctcLogits;
  final List<int> ctcShape;
  final int blankId;
  final int sosId;
  final int eosId;
  final int beamSize;
  final int tokenPruneSize;
  final double ctcWeight;
  final double decoderWeight;

  late final _CtcLogProbs _ctcLogProbs = _CtcLogProbs(ctcLogits, ctcShape);
  late final _CtcDpState _seedCtcState = _seedState();

  JointCtcTransformerBeamSearch({
    required this.decoder,
    required this.ctcLogits,
    required this.ctcShape,
    required this.blankId,
    required this.sosId,
    required this.eosId,
    this.beamSize = 10,
    this.tokenPruneSize = 25,
    this.ctcWeight = 0.3,
    this.decoderWeight = 0.7,
  });

  Future<Int32List> decode() async {
    final initialCaches = await decoder.initialCaches();
    if (initialCaches.length != decoder.numLayers) {
      throw StateError(
        'runner.initialCaches returned ${initialCaches.length} entries but '
        'runner.numLayers is ${decoder.numLayers}',
      );
    }

    var active = <_JointHypothesis>[
      _JointHypothesis(
        yseq: [sosId],
        tokens: const [],
        decoderScore: 0.0,
        ctcState: _seedCtcState,
        caches: initialCaches,
      ),
    ];
    final ended = <_JointHypothesis>[];
    final maxOutputLength = max(1, _ctcLogProbs.time);
    bool validatedRunnerOutput = false;

    for (int step = 0; step < maxOutputLength; step++) {
      final isFinalStep = step == maxOutputLength - 1;
      final candidates = <_JointHypothesis>[];

      for (final hyp in active) {
        final result = await decoder.step(
          prefix: hyp.yseq,
          caches: hyp.caches,
        );
        if (!validatedRunnerOutput) {
          if (result.logProbs.length != decoder.vocab) {
            throw StateError(
              'runner.step returned logProbs of length '
              '${result.logProbs.length} but runner.vocab is ${decoder.vocab}',
            );
          }
          if (result.caches.length != decoder.numLayers) {
            throw StateError(
              'runner.step returned ${result.caches.length} caches but '
              'runner.numLayers is ${decoder.numLayers}',
            );
          }
          validatedRunnerOutput = true;
        }
        final logProbs = result.logProbs;
        final nextCaches = result.caches;

        if (isFinalStep) {
          // Force every still-active hyp into `ended` so the beam always
          // resolves to a complete sequence at maxlen.
          candidates.add(
            _JointHypothesis(
              yseq: [...hyp.yseq, eosId],
              tokens: hyp.tokens,
              decoderScore: hyp.decoderScore + logProbs[eosId],
              ctcState: hyp.ctcState,
              caches: nextCaches,
              ended: true,
            ),
          );
          continue;
        }

        final topIds = LogMath.topTokenIdsAtFrame(
          logProbs,
          0,
          logProbs.length,
          tokenPruneSize,
        );
        bool sawEos = false;

        void addCandidate(int tokenId) {
          if (tokenId == blankId) return;
          if (tokenId == sosId && sosId != eosId) return;

          final nextYseq = [...hyp.yseq, tokenId];

          if (tokenId == eosId) {
            sawEos = true;
            candidates.add(
              _JointHypothesis(
                yseq: nextYseq,
                tokens: hyp.tokens,
                decoderScore: hyp.decoderScore + logProbs[tokenId],
                ctcState: hyp.ctcState,
                caches: nextCaches,
                ended: true,
              ),
            );
            return;
          }

          final nextTokens = [...hyp.tokens, tokenId];
          final nextCtc = _extendCtcState(hyp.ctcState, tokenId);
          candidates.add(
            _JointHypothesis(
              yseq: nextYseq,
              tokens: nextTokens,
              decoderScore: hyp.decoderScore + logProbs[tokenId],
              ctcState: nextCtc,
              caches: nextCaches,
            ),
          );
        }

        for (int i = 0; i < topIds.length; i++) {
          addCandidate(topIds[i]);
        }
        if (!sawEos && eosId >= 0 && eosId < logProbs.length) {
          addCandidate(eosId);
        }
      }

      candidates.sort((a, b) => _score(b).compareTo(_score(a)));
      ended.addAll(candidates.where((hyp) => hyp.ended));
      active = candidates.where((hyp) => !hyp.ended).take(beamSize).toList();

      if (active.isEmpty) break;
      if (_endDetect(ended, step)) break;
    }

    final all = [...ended, ...active]
      ..sort((a, b) => _score(b).compareTo(_score(a)));

    return Int32List.fromList(all.first.tokens);
  }

  double _score(_JointHypothesis hyp) {
    final ctc = hyp.ctcState.score;
    if (ctc == LogMath.logZero) {
      if (ctcWeight > 0) return LogMath.logZero;
      return decoderWeight * hyp.decoderScore;
    }
    return decoderWeight * hyp.decoderScore + ctcWeight * ctc;
  }

  /// Espnet `end_detect`: stop once ended-hyp scores plateau across the last
  /// `m` lengths (each within `dEnd` of the global best).
  bool _endDetect(List<_JointHypothesis> endedHyps, int step,
      {int m = 3, double dEnd = -10.0}) {
    if (endedHyps.isEmpty) return false;

    double bestScore = double.negativeInfinity;
    for (final h in endedHyps) {
      final s = _score(h);
      if (s > bestScore) bestScore = s;
    }

    int count = 0;
    for (int offset = 0; offset < m; offset++) {
      final yseqLength = step + 1 - offset;
      if (yseqLength <= 0) break;

      double bestAtLen = double.negativeInfinity;
      for (final h in endedHyps) {
        if (h.yseq.length != yseqLength) continue;
        final s = _score(h);
        if (s > bestAtLen) bestAtLen = s;
      }
      if (bestAtLen == double.negativeInfinity) continue;

      if (bestAtLen - bestScore < dEnd) count++;
    }

    return count == m;
  }

  _CtcDpState _seedState() {
    final t = _ctcLogProbs.time;
    final lastB = Float64List(t);
    final lastTn = Float64List(t)..fillRange(0, t, LogMath.logZero);
    lastB[0] = _ctcLogProbs.at(0, blankId);
    for (int i = 1; i < t; i++) {
      lastB[i] = lastB[i - 1] + _ctcLogProbs.at(i, blankId);
    }
    return _CtcDpState(
      lastB: lastB,
      lastTn: lastTn,
      lastToken: -1,
      prefixLength: 0,
    );
  }

  /// Incremental CTC forward step: O(T) per extension by computing only the
  /// new trailing token + blank columns of the trellis from the parent state.
  _CtcDpState _extendCtcState(_CtcDpState old, int c) {
    final t = _ctcLogProbs.time;
    final newLastTn = Float64List(t);
    final newLastB = Float64List(t)..fillRange(0, t, LogMath.logZero);

    if (old.prefixLength == 0) {
      newLastTn[0] = _ctcLogProbs.at(0, c);
    } else {
      newLastTn[0] = LogMath.logZero;
    }

    final canSkipFromTn = c != old.lastToken;

    for (int i = 1; i < t; i++) {
      var sum = LogMath.logAdd(newLastTn[i - 1], old.lastB[i - 1]);
      if (canSkipFromTn) {
        sum = LogMath.logAdd(sum, old.lastTn[i - 1]);
      }
      newLastTn[i] = sum + _ctcLogProbs.at(i, c);

      newLastB[i] =
          LogMath.logAdd(newLastB[i - 1], newLastTn[i - 1]) +
              _ctcLogProbs.at(i, blankId);
    }

    return _CtcDpState(
      lastB: newLastB,
      lastTn: newLastTn,
      lastToken: c,
      prefixLength: old.prefixLength + 1,
    );
  }
}

class _CtcLogProbs {
  final List<double> logits;
  final int time;
  final int vocab;
  late final Float64List _logProbs;

  _CtcLogProbs(this.logits, List<int> shape)
      : time = _timeFromShape(shape),
        vocab = _vocabFromShape(shape) {
    final layout = CtcLogitsLayout(time: time, vocab: vocab);
    layout.validateLogitsLength(logits.length);
    _logProbs = LogMath.logSoftmaxAllFrames(logits, layout);
  }

  double at(int timeIndex, int vocabIndex) {
    return _logProbs[timeIndex * vocab + vocabIndex];
  }

  static int _timeFromShape(List<int> shape) {
    if (shape.length == 2) return shape[0];
    if (shape.length == 3 && shape[0] == 1) return shape[1];
    if (shape.length == 3 && shape[1] == 1) return shape[0];
    throw ArgumentError('Unsupported CTC logits shape: $shape');
  }

  static int _vocabFromShape(List<int> shape) {
    if (shape.length == 2) return shape[1];
    if (shape.length == 3) return shape[2];
    throw ArgumentError('Unsupported CTC logits shape: $shape');
  }
}

class _CtcDpState {
  final Float64List lastB;
  final Float64List lastTn;
  final int lastToken;
  final int prefixLength;

  const _CtcDpState({
    required this.lastB,
    required this.lastTn,
    required this.lastToken,
    required this.prefixLength,
  });

  double get score {
    final last = lastB.length - 1;
    return LogMath.logAdd(lastTn[last], lastB[last]);
  }
}

class _JointHypothesis {
  final List<int> yseq;
  final List<int> tokens;
  final double decoderScore;
  final _CtcDpState ctcState;
  final List<Object> caches;
  final bool ended;

  const _JointHypothesis({
    required this.yseq,
    required this.tokens,
    required this.decoderScore,
    required this.ctcState,
    required this.caches,
    this.ended = false,
  });
}
