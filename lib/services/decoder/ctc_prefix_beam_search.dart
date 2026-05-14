import 'dart:typed_data';

import 'ctc_logits.dart';

class CtcPrefixBeamSearch {
  static Int32List decode(
    List<double> logProbs, {
    required List<int> shape,
    required int blankId,
    int? eosId,
    int beamSize = 20,
    int tokenPruneSize = 40,
    Set<int> suppressedTokenIds = const {},
  }) {
    final layout = CtcLogitsLayout.fromShape(shape);
    final vocab = layout.vocab;

    if (blankId < 0 || blankId >= vocab) {
      throw ArgumentError('blankId $blankId is outside vocab size $vocab');
    }

    final frames = LogMath.logSoftmaxAllFrames(logProbs, layout);

    var beam = <_Prefix, _BeamState>{
      _Prefix.empty: _BeamState(blank: 0.0, nonBlank: LogMath.logZero),
    };

    for (int t = 0; t < layout.time; t++) {
      final base = t * vocab;
      final blankLogProb = frames[base + blankId];
      final topTokens = LogMath.topTokenIdsAtFrame(
        frames,
        base,
        vocab,
        tokenPruneSize,
      );

      final next = <_Prefix, _BeamState>{};

      beam.forEach((prefix, state) {
        final prefixScore = state.score;
        _mergeBlank(next, prefix, prefixScore + blankLogProb);

        final lastTokenId = prefix.lastTokenId;

        for (final tokenId in topTokens) {
          if (tokenId == blankId) continue;
          if (suppressedTokenIds.contains(tokenId)) continue;

          final tokenLogProb = frames[base + tokenId];

          if (tokenId == lastTokenId) {
            _mergeNonBlank(next, prefix, state.nonBlank + tokenLogProb);
            _mergeNonBlank(
              next,
              prefix.extend(tokenId),
              state.blank + tokenLogProb,
            );
          } else {
            _mergeNonBlank(
              next,
              prefix.extend(tokenId),
              prefixScore + tokenLogProb,
            );
          }
        }
      });

      beam = _pruneBeam(next, beamSize);
    }

    _Prefix bestPrefix = _Prefix.empty;
    double bestScore = double.negativeInfinity;
    beam.forEach((prefix, state) {
      final score = state.score;
      if (score > bestScore) {
        bestScore = score;
        bestPrefix = prefix;
      }
    });

    final ids = bestPrefix.toList();
    if (ids.isNotEmpty && eosId != null && ids.last == eosId) {
      ids.removeLast();
    }
    return Int32List.fromList(ids);
  }

  static Map<_Prefix, _BeamState> _pruneBeam(
    Map<_Prefix, _BeamState> beam,
    int beamSize,
  ) {
    if (beam.length <= beamSize) return beam;

    final entries = beam.entries.toList(growable: false)
      ..sort((a, b) => b.value.score.compareTo(a.value.score));

    final pruned = <_Prefix, _BeamState>{};
    for (int i = 0; i < beamSize; i++) {
      pruned[entries[i].key] = entries[i].value;
    }
    return pruned;
  }

  static void _mergeBlank(
    Map<_Prefix, _BeamState> beam,
    _Prefix prefix,
    double blank,
  ) {
    final current = beam[prefix];
    if (current == null) {
      beam[prefix] = _BeamState(blank: blank, nonBlank: LogMath.logZero);
    } else {
      beam[prefix] = _BeamState(
        blank: LogMath.logAdd(current.blank, blank),
        nonBlank: current.nonBlank,
      );
    }
  }

  static void _mergeNonBlank(
    Map<_Prefix, _BeamState> beam,
    _Prefix prefix,
    double nonBlank,
  ) {
    final current = beam[prefix];
    if (current == null) {
      beam[prefix] = _BeamState(blank: LogMath.logZero, nonBlank: nonBlank);
    } else {
      beam[prefix] = _BeamState(
        blank: current.blank,
        nonBlank: LogMath.logAdd(current.nonBlank, nonBlank),
      );
    }
  }
}

class _Prefix {
  static final _Prefix empty = _Prefix._(null, -1, 0, 0);

  final _Prefix? parent;
  final int tokenId;
  final int depth;
  final int _hash;

  const _Prefix._(this.parent, this.tokenId, this.depth, this._hash);

  int get lastTokenId => tokenId;

  _Prefix extend(int id) {
    final nextHash = (_hash * 31 + id) & 0x3FFFFFFF;
    return _Prefix._(this, id, depth + 1, nextHash);
  }

  List<int> toList() {
    if (depth == 0) return <int>[];
    final ids = List<int>.filled(depth, 0);
    _Prefix? node = this;
    for (int i = depth - 1; i >= 0 && node != null && node.parent != null;
        i--) {
      ids[i] = node.tokenId;
      node = node.parent;
    }
    return ids;
  }

  @override
  int get hashCode => _hash;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _Prefix) return false;
    if (depth != other.depth) return false;
    if (_hash != other._hash) return false;

    _Prefix? a = this;
    _Prefix? b = other;
    while (a != null && b != null && a.depth > 0) {
      if (a.tokenId != b.tokenId) return false;
      a = a.parent;
      b = b.parent;
    }
    return true;
  }
}

class _BeamState {
  final double blank;
  final double nonBlank;
  final double score;

  _BeamState({required this.blank, required this.nonBlank})
      : score = LogMath.logAdd(blank, nonBlank);
}
