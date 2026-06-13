import 'dart:typed_data';

class TransformerDecoderStep {
  /// Log-softmaxed distribution over the vocab for the next token. The joint
  /// search adds these values into hypothesis scores and feeds them to a
  /// top-k pruner, so the runner must normalize before returning (raw logits
  /// would produce incorrect joint scores).
  final Float64List logProbs;
  final List<Object> caches;

  const TransformerDecoderStep({required this.logProbs, required this.caches});
}

abstract class TransformerDecoderRunner {
  int get vocab;
  int get numLayers;

  Future<List<Object>> initialCaches();

  Future<TransformerDecoderStep> step({
    required List<int> prefix,
    required List<Object> caches,
  });

  Future<void> dispose();
}
