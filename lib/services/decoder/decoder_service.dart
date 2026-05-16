import 'dart:typed_data';

import 'ctc_greedy.dart';
import 'ctc_logits.dart';
import 'ctc_prefix_beam_search.dart';
import 'joint_ctc_transformer_beam_search.dart';
import 'transformer_decoder_runner.dart';

export 'transformer_decoder_runner.dart'
    show TransformerDecoderRunner, TransformerDecoderStep;

enum CtcDecodingMode { greedy, prefixBeam }

class DecoderService {
  final int blankId;
  final int? eosId;
  final int beamSize;
  final int tokenPruneSize;
  final Set<int> suppressedTokenIds;

  const DecoderService({
    this.blankId = 0,
    this.eosId,
    this.beamSize = 20,
    this.tokenPruneSize = 40,
    this.suppressedTokenIds = const {},
  });

  /// Sync CTC-only decoding. `logProbs` is flat row-major `(T, V)` or
  /// `(1, T, V)` of either log-softmax or raw logits.
  Int32List decode(
    List<double> logProbs, {
    required List<int> shape,
    CtcDecodingMode mode = CtcDecodingMode.prefixBeam,
  }) {
    switch (mode) {
      case CtcDecodingMode.greedy:
        return CtcGreedyDecoder.decode(
          logProbs,
          shape: shape,
          blankId: blankId,
          eosId: eosId,
        );
      case CtcDecodingMode.prefixBeam:
        return CtcPrefixBeamSearch.decode(
          logProbs,
          shape: shape,
          blankId: blankId,
          eosId: eosId,
          beamSize: beamSize,
          tokenPruneSize: tokenPruneSize,
          suppressedTokenIds: suppressedTokenIds,
        );
    }
  }

  /// Joint CTC + autoregressive-transformer beam search. The transformer is
  /// abstracted as a [TransformerDecoderRunner] so the algorithm stays free
  /// of any ONNX / TF-Lite / FFI dependencies.
  ///
  /// `sosId` defaults to `eosId` (espnet's typical `<sos/eos>` shared token).
  /// `ctcWeight` and `decoderWeight` are espnet defaults (0.3 / 0.7).
  Future<Int32List> decodeJoint(
    List<double> ctcLogProbs, {
    required List<int> shape,
    required TransformerDecoderRunner runner,
    int? sosId,
    int? beamSize,
    int? tokenPruneSize,
    double ctcWeight = 0.3,
    double decoderWeight = 0.7,
  }) async {
    final eos = eosId;
    if (eos == null) {
      throw StateError(
        'decodeJoint requires DecoderService.eosId to be set so the search '
        'knows when to terminate hypotheses.',
      );
    }
    final layout = CtcLogitsLayout.fromShape(shape);
    layout.validateLogitsLength(ctcLogProbs.length);
    if (runner.vocab != layout.vocab) {
      throw ArgumentError(
        'runner.vocab (${runner.vocab}) does not match CTC vocab '
        '(${layout.vocab}). The decoder and CTC heads must share a tokenizer.',
      );
    }
    final sos = sosId ?? eos;
    if (eos < 0 || eos >= layout.vocab) {
      throw ArgumentError('eosId $eos is outside vocab size ${layout.vocab}');
    }
    if (sos < 0 || sos >= layout.vocab) {
      throw ArgumentError('sosId $sos is outside vocab size ${layout.vocab}');
    }
    final effectiveBeam = beamSize ?? this.beamSize ~/ 2;
    final effectivePrune = tokenPruneSize ?? this.tokenPruneSize ~/ 2;
    if (effectiveBeam < 1) {
      throw ArgumentError('beamSize must be >= 1 (got $effectiveBeam)');
    }
    if (effectivePrune < 1) {
      throw ArgumentError(
        'tokenPruneSize must be >= 1 (got $effectivePrune)',
      );
    }
    return JointCtcTransformerBeamSearch(
      decoder: runner,
      ctcLogits: ctcLogProbs,
      ctcShape: shape,
      blankId: blankId,
      sosId: sos,
      eosId: eos,
      beamSize: effectiveBeam,
      tokenPruneSize: effectivePrune,
      ctcWeight: ctcWeight,
      decoderWeight: decoderWeight,
    ).decode();
  }
}
