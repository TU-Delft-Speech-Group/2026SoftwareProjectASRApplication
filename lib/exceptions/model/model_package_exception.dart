class ModelPackageException implements Exception {
  const ModelPackageException(this.message);

  final String message;

  @override
  String toString() => 'ModelPackageException: $message';
}
