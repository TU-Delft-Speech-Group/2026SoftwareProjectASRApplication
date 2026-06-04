/* Wraps a failure that occurred at a named stage of the ASR pipeline.
    Thrown by StreamingTranscriptionService when an exception propagates out
    of one of the pipeline stages (encode, decode, tokenise) such that callers
    can identify which stage failed without inspecting the cause's type.
*/
class PipelineStageException implements Exception {
  const PipelineStageException({
    required this.stage,
    required this.cause,
    this.stackTrace,
  });

  // the pipeline stage where the failure occurred;
  // one of: 'encode', 'decode', 'tokenise'.
  final String stage;

  // exception thrown by the failing stage
  final Object cause;

  // the stack trace captured at the point of failure, preserved from the
  // original throw so callers can diagnose the source without unwrapping
  final StackTrace? stackTrace;

  @override
  String toString() => 'Pipeline failed at $stage stage: $cause';
}
