abstract class VadService {
  Future<void> initialize();

  // returns true if speech is detected in the given samples;
  // expects 16 kHz mono audio normalised to the –1..1 range;
  // state carries over between calls, call reset() between recording sessions;
  Future<bool> isSpeech(List<double> samples);

  // reset internal state between recording sessions
  Future<void> reset();

  Future<void> dispose();
}
