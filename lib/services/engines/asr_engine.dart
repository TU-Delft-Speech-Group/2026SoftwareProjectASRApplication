import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';

/// Builds a runtime for one ASR model family.
abstract interface class AsrEngine {
  /// Manifest model type handled by this engine, for example `espnet`.
  String get modelType;

  Future<AsrRuntime> createRuntime(Model model);
}
