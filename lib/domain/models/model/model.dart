import 'package:asr_application/domain/models/model/model_files.dart';
import 'package:asr_application/domain/models/model/model_metadata.dart';

class Model {
  const Model({required this.name, required this.files, this.metadata});

  final String name;
  final ModelFiles files;

  /// Vocab metadata from the package manifest, or null for legacy (format
  /// version 1) packages without a "vocab" block.
  final ModelMetadata? metadata;
}
