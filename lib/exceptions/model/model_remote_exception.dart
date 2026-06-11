class ModelRemoteException implements Exception {
  const ModelRemoteException(this.message);

  final String message;

  @override
  String toString() => 'ModelRemoteException: $message';
}
