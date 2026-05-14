import 'dart:typed_data';

class TransformerDecoderStep {
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
}
