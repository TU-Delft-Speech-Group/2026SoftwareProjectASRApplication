import 'dart:math';

// Throwaway latency-measurement result. See lib/debug/latency/README.
class LatencyResult {
  LatencyResult({
    required this.label,
    required this.audioMs,
    required this.totalProcessMs,
    required this.perChunkMs,
    required this.firstResponseMs,
    required this.transcript,
  });

  final String label;
  // Audio duration fed (bundled) or recording wall-clock (live), in ms.
  final double audioMs;
  // Sum of per-chunk process() time (encode + decode), in ms.
  final double totalProcessMs;
  // Per-decode-tick process() latency, in ms.
  final List<double> perChunkMs;
  // Wall-clock from start to the first non-empty hypothesis, in ms.
  final int? firstResponseMs;
  final String transcript;

  // Real-time factor: processing time / audio duration. < 1 = faster than
  // real-time (keeps up with a live stream).
  double get rtf => audioMs == 0 ? 0 : totalProcessMs / audioMs;
  int get chunks => perChunkMs.length;
  double get avgChunkMs =>
      perChunkMs.isEmpty ? 0 : totalProcessMs / perChunkMs.length;
  double get maxChunkMs => perChunkMs.isEmpty ? 0 : perChunkMs.reduce(max);

  double percentile(double p) {
    if (perChunkMs.isEmpty) return 0;
    final sorted = [...perChunkMs]..sort();
    final rank = (p / 100.0) * (sorted.length - 1);
    final lo = rank.floor();
    final hi = rank.ceil();
    if (lo == hi) return sorted[lo];
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
  }

  double get p50 => percentile(50);
  double get p90 => percentile(90);
}
