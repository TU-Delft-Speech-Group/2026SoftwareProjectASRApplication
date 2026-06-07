final class RemoteModelServiceConfig {
  const RemoteModelServiceConfig({
    this.directory = 'models_remote',
    this.allowedHosts = const {'huggingface.co'},
    this.allowedExtensions = const {'.asrmodel'},
  });

  final String directory;
  final Set<String> allowedHosts;
  final Set<String> allowedExtensions;
}
