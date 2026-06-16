/// Minimal lifecycle contract shared by ASR pipelines.
///
/// Engine-specific implementations can expose richer methods, such as ESPnet's
/// `encode` method, without forcing every future engine into an encoder/CTC
/// shape.
abstract interface class AsrPipeline {
  bool get isInitialized;

  Future<void> initialize();

  Future<void> dispose();
}
