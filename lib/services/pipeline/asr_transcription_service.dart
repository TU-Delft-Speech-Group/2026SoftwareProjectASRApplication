import 'dart:typed_data';

/*
  Result of a single streaming transcription process() call.
  [OngoingResult] means transcription is in progress; [confirmedText] holds the
  stable prefix so far, and [hypothesis] is the full current decoder output.
  [SegmentResult] means a segment boundary was reached and [confirmedText] is
  the text committed for that segment.
*/
sealed class StreamResult {
  const StreamResult({required this.confirmedText, required this.hypothesis});

  final String confirmedText;
  final String hypothesis;
}

final class OngoingResult extends StreamResult {
  const OngoingResult({
    required super.confirmedText,
    required super.hypothesis,
  });
}

final class SegmentResult extends StreamResult {
  const SegmentResult({
    required super.confirmedText,
    required super.hypothesis,
  });
}

/// Streaming transcription API consumed by the recording coordinator.
///
/// Engine-specific runtimes can implement this with CTC, encoder-decoder,
/// cloud, or any other transcription strategy as long as they accept the audio
/// feature frames produced by the recorder pipeline.
abstract interface class AsrTranscriptionService {
  String get confirmedText;

  Future<StreamResult?> process(List<Float32List> allFrames);

  void reset();

  void commit();

  void skipTo(int frameCount);
}
