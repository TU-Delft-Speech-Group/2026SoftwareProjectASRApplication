/// Thrown when a user picks a file that is not an .asrmodel package.
///
/// Android (and a user who widens the file-type filter on other platforms) can
/// pick any file, so the picked path is validated before installation and this
/// is surfaced to show a clear "wrong file type" message.
class InvalidModelFileException implements Exception {
  const InvalidModelFileException(this.path);

  final String path;

  @override
  String toString() =>
      'InvalidModelFileException: $path is not an .asrmodel file';
}
