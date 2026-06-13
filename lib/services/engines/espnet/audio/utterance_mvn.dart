import 'dart:typed_data';

/// Per-utterance mean normalization across the time axis.
/// Mirrors espnet2 UtteranceMVN with norm_means=true, norm_vars=false.
class UtteranceMvn {
  const UtteranceMvn();

  List<Float32List> apply(List<Float32List> frames) {
    if (frames.isEmpty) return frames;
    final featureDim = frames.first.length;
    final means = Float64List(featureDim);
    for (final frame in frames) {
      for (var d = 0; d < featureDim; d++) {
        means[d] += frame[d];
      }
    }
    final frameCount = frames.length;
    for (var d = 0; d < featureDim; d++) {
      means[d] /= frameCount;
    }
    return List<Float32List>.generate(frameCount, (t) {
      final src = frames[t];
      final dst = Float32List(featureDim);
      for (var d = 0; d < featureDim; d++) {
        dst[d] = src[d] - means[d];
      }
      return dst;
    });
  }
}
