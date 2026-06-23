import 'package:asr_application/domain/models/model/model_list.dart';

String? decideActiveModel(ModelList modelList, String? currentModel) {
  final availableModels = modelList.modelNames;

  if (availableModels.isEmpty) return null;

  if (!availableModels.contains(currentModel)) currentModel = null;

  currentModel ??= availableModels.singleOrNull;

  return currentModel;
}
