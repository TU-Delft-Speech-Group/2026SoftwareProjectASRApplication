import 'package:flutter/material.dart';

import '../../../services/model_install/model_install_controller.dart';
import '../../../utils/result.dart';
import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

class SettingsModelList extends StatefulWidget {
  const SettingsModelList({
    super.key,
    this.modelController,
    this.onModelSelected,
  });

  final ModelInstallController? modelController;
  final Future<void> Function(String modelName)? onModelSelected;

  @override
  State<SettingsModelList> createState() => _SettingsModelListState();
}

class _SettingsModelListState extends State<SettingsModelList> {
  late Future<List<String>> _modelsFuture;

  @override
  void initState() {
    super.initState();
    widget.modelController?.addListener(_handleModelControllerChanged);
    _modelsFuture = _loadModels();
  }

  @override
  void didUpdateWidget(SettingsModelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelController == widget.modelController) return;

    oldWidget.modelController?.removeListener(_handleModelControllerChanged);
    widget.modelController?.addListener(_handleModelControllerChanged);
    _modelsFuture = _loadModels();
  }

  @override
  void dispose() {
    widget.modelController?.removeListener(_handleModelControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settings__languageModel,
          style: TextStyle(
            color: context.colors.black,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<String>>(
          future: _modelsFuture,
          builder: (context, snapshot) {
            final models = snapshot.data ?? const <String>[];
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: models.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final modelName = models[index];
                return _ModelCard(
                  id: modelName,
                  name: modelName,
                  selected:
                      widget.modelController?.activeModelName == modelName,
                  onPressed: () => _selectModel(modelName),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<List<String>> _loadModels() async {
    final controller = widget.modelController;
    if (controller == null) return const [];

    final result = await controller.getModelList();
    return switch (result) {
      Ok(:final value) => value.modelNames.toList(),
      Error() => const <String>[],
    };
  }

  void _handleModelControllerChanged() {
    if (!mounted) return;
    setState(() {
      _modelsFuture = _loadModels();
    });
  }

  Future<void> _selectModel(String modelName) async {
    if (widget.modelController?.activeModelName == modelName) return;

    widget.modelController?.selectModel(modelName);
    await widget.onModelSelected?.call(modelName);
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.id,
    required this.name,
    required this.onPressed,
    this.selected = false,
  });

  final String id;
  final String name;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? context.colors.blue : context.colors.black;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: context.colors.black,
                            fontSize: context.fontSize.body,
                            fontFamily: context.fontFamily.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      key: ValueKey('settings-model-selected-$id'),
                      color: context.colors.blue,
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
