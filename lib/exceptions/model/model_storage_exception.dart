class ModelStorageException implements Exception {
  const ModelStorageException(this.message);

  final String message;

  @override
  String toString() => 'ModelStorageException: $message';
}
