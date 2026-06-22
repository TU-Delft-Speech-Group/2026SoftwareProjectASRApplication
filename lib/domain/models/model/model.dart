import 'package:asr_application/domain/models/model/model_files.dart';
import 'package:asr_application/domain/models/model/model_metadata.dart';
import 'package:asr_application/domain/models/model/model_type.dart';

class Model {
  const Model({
    required this.name,
    required this.files,
    this.modelType = ModelType.espnet,
    this.metadata,
  });

  final String name;
  final ModelFiles files;
  final String modelType;

  /// Vocab metadata from the package manifest, or null for legacy (format
  /// version 1) packages without a "vocab" block.
  final ModelMetadata? metadata;
}
