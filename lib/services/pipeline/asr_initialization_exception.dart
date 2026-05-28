/// Wraps failures that occur while constructing an [AsrRuntime]
class AsrInitializationException implements Exception {
  const AsrInitializationException({
    required this.stage,
    required this.cause,
    required this.stackTrace,
  });

  final String stage;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => 'Could not initialize ASR during $stage: $cause';
}
