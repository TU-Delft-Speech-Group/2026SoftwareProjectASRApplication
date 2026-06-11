/// Shared peak-amplitude threshold and chunk granularity for silence
/// detection. Used by the live [RecorderService] (reading from the
/// microphone) and the benchmark streaming driver (reading from WAV files)
/// so the two stay in sync.
class SilenceDetector {
  // Raised to 1500 (~4.6 % of full scale) so typical laptop background noise
  // (fans, room tone) is classified as silence; normal speech peaks well
  // above. Tune down if soft speakers are cut off too early.
  static const int thresholdPeakInt16 = 1500;

  // Same threshold as a normalised peak in [-1, 1] for callers that work in
  // floating-point samples.
  static const double thresholdPeak = thresholdPeakInt16 / 32768.0;

  // Each chunk from the record plugin (and each silence-detection slice in
  // the benchmark driver) holds ~100ms of audio at 16kHz mono.
  static const int chunkDurationMs = 100;
  static const Duration chunkDuration = Duration(
    milliseconds: chunkDurationMs,
  );
}
