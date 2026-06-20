import 'package:flutter/material.dart';

import '../../../services/model_install/model_install_controller.dart';
import '../../../utils/result.dart';
import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

class SettingsModelList extends StatefulWidget {
  const SettingsModelList({
    super.key,
    required this.modelController,
    this.onModelSelected,
  });

  final ModelInstallController modelController;
  final Future<void> Function(String modelName)? onModelSelected;

  @override
  State<SettingsModelList> createState() => _SettingsModelListState();
}

class _SettingsModelListState extends State<SettingsModelList> {
  late Future<List<String>> _modelsFuture;

  @override
  void initState() {
    super.initState();
    widget.modelController.addListener(_handleModelControllerChanged);
    _modelsFuture = _loadModels();
  }

  @override
  void didUpdateWidget(SettingsModelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelController == widget.modelController) return;

    oldWidget.modelController.removeListener(_handleModelControllerChanged);
    widget.modelController.addListener(_handleModelControllerChanged);
    _modelsFuture = _loadModels();
  }

  @override
  void dispose() {
    widget.modelController.removeListener(_handleModelControllerChanged);
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
                  name: modelName,
                  selected: widget.modelController.activeModelName == modelName,
                  onPressed: () => _selectModel(modelName),
                  onRenamePressed: () => _renameModel(modelName),
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
    if (widget.modelController.activeModelName == modelName) return;

    widget.modelController.selectModel(modelName);
    await widget.onModelSelected?.call(modelName);
  }

  Future<void> _renameModel(String currentName) async {
    final controller = widget.modelController;

    final renamedName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameModelDialog(initialName: currentName),
    );
    if (!mounted || renamedName == null || renamedName == currentName) return;

    final result = await controller.renameModel(currentName, renamedName);
    if (!mounted) return;

    switch (result) {
      case Ok():
        setState(() {
          _modelsFuture = _loadModels();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settings__modelRenamed(renamedName)),
          ),
        );
      case Error(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.name,
    required this.onPressed,
    required this.onRenamePressed,
    this.selected = false,
  });

  final String name;
  final VoidCallback onPressed;
  final VoidCallback onRenamePressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? context.colors.blue : context.colors.black;
    const borderWidth = 3.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.all(borderWidth),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
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
                            if (selected) ...[
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.settings__selectedModel,
                                style: TextStyle(
                                  color: context.colors.foregroundLight,
                                  fontSize: context.fontSize.small,
                                  fontFamily: context.fontFamily.body,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const _ModelCardSeparator(),
                    _RenameModelButton(
                      key: ValueKey('settings-model-rename-$name'),
                      onPressed: onRenamePressed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelCardSeparator extends StatelessWidget {
  const _ModelCardSeparator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 2, child: ColoredBox(color: context.colors.black));
  }
}

class _RenameModelButton extends StatelessWidget {
  const _RenameModelButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.settings__renameModel;

    return AspectRatio(
      aspectRatio: 1,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: label,
          child: ColoredBox(
            color: context.colors.yellow,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                child: Center(
                  child: Icon(Icons.edit_outlined, color: context.colors.black),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RenameModelDialog extends StatefulWidget {
  const _RenameModelDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameModelDialog> createState() => _RenameModelDialogState();
}

class _RenameModelDialogState extends State<_RenameModelDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.settings__renameModel),
      content: TextField(
        autofocus: true,
        controller: _controller,
        decoration: InputDecoration(
          labelText: context.l10n.settings__modelName,
          errorText: _errorText,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.settings__cancel),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: Text(context.l10n.settings__rename),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = context.l10n.settings__modelNameRequired;
      });
      return;
    }

    Navigator.of(context).pop(name);
  }
}
