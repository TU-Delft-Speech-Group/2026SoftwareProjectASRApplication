final class LocalModelStorageConfig {
  const LocalModelStorageConfig({
    this.directory = 'models',

    this.ctcFilePath = 'ctc.onnx',
    this.encoderFilePath = 'encoder.onnx',
    this.decoderFilePath = 'decoder.onnx',
    this.vocabFilePath = 'vocab.txt',
    this.manifestFilePath = 'manifest.json',
  });

  final String directory;

  final String ctcFilePath;
  final String encoderFilePath;
  final String decoderFilePath;
  final String vocabFilePath;

  /// The package manifest, preserved alongside the model files so the app can
  /// read its vocab metadata (special-token ids) after installation.
  final String manifestFilePath;
}
