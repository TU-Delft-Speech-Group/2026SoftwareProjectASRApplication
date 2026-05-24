import 'dart:collection';

class ModelList {
  const ModelList({required this.modelNames});

  final UnmodifiableListView<String> modelNames;
}
