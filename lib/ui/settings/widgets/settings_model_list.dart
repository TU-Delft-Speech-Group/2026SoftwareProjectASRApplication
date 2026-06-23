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
    this.onModelDeleted,
  });

  final ModelInstallController modelController;
  final Future<Result<void>> Function(String modelName)? onModelSelected;

  // Called after a model is deleted, so the caller can reload or clear the
  // active ASR runtime to match the (possibly changed) active model.
  final Future<void> Function()? onModelDeleted;

  @override
  State<SettingsModelList> createState() => _SettingsModelListState();
}

class _SettingsModelListState extends State<SettingsModelList> {
  late List<String> _models;

  @override
  void initState() {
    super.initState();
    widget.modelController.addListener(_handleModelControllerChanged);
    _models = _loadModels();
  }

  @override
  void didUpdateWidget(SettingsModelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelController == widget.modelController) return;

    oldWidget.modelController.removeListener(_handleModelControllerChanged);
    widget.modelController.addListener(_handleModelControllerChanged);
    _models = _loadModels();
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
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _models.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final modelName = _models[index];
            return _ModelCard(
              name: modelName,
              selected: widget.modelController.activeModelName == modelName,
              onPressed: () async => await _selectModel(modelName),
              onRenamePressed: () async => await _renameModel(modelName),
              onDelete: () async =>
                  await _confirmAndDeleteModel(context, modelName),
            );
          },
        ),
      ],
    );
  }

  List<String> _loadModels() {
    final controller = widget.modelController;

    return controller.getModelList().modelNames;
  }

  void _handleModelControllerChanged() {
    if (!mounted) return;
    setState(() {
      _models = _loadModels();
    });
  }

  Future<void> _selectModel(String modelName) async {
    if (widget.modelController.activeModelName == modelName) return;

    await widget.modelController.selectModel(modelName);
    final result = await widget.onModelSelected?.call(modelName);
    if (!mounted || result == null) return;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    switch (result) {
      case Ok():
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.settings__modelLoaded)),
        );
      case Error(:final error):
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
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

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    switch (result) {
      case Ok():
        setState(() {
          _models = _loadModels();
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.settings__modelRenamed(renamedName)),
          ),
        );
      case Error(:final error):
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _confirmAndDeleteModel(
    BuildContext context,
    String modelName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.settings__deleteModelConfirmTitle),
        content: Text(
          dialogContext.l10n.settings__deleteModelConfirmMessage(modelName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.settings__cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.settings__deleteModel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _deleteModel(modelName);
  }

  Future<void> _deleteModel(String modelName) async {
    final wasActive = widget.modelController.activeModelName == modelName;
    final result = await widget.modelController.deleteModel(modelName);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    switch (result) {
      case Ok():
        setState(() {
          _models = _loadModels();
        });
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.settings__deleteModelSuccess)),
        );
        if (wasActive) await widget.onModelDeleted?.call();
      case Error(:final error):
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.errors__deleteModelFailed)),
        );
        debugPrint('Failed to delete model $modelName: $error');
    }
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.name,
    required this.onPressed,
    required this.onRenamePressed,
    required this.onDelete,
    this.selected = false,
  });

  final String name;
  final VoidCallback onPressed;
  final VoidCallback onRenamePressed;
  final VoidCallback onDelete;
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.black,
                                fontSize: context.fontSize.body,
                                fontFamily: context.fontFamily.body,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Visibility(
                              visible: selected,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: Text(
                                context.l10n.settings__selectedModel,
                                style: TextStyle(
                                  color: context.colors.foregroundLight,
                                  fontSize: context.fontSize.small,
                                  fontFamily: context.fontFamily.body,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const _ModelCardSeparator(),
                    _RenameModelButton(
                      key: ValueKey('settings-model-rename-$name'),
                      onPressed: onRenamePressed,
                    ),
                    const _ModelCardSeparator(),
                    _DeleteModelButton(
                      key: ValueKey('settings-model-delete-$name'),
                      onPressed: onDelete,
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

class _DeleteModelButton extends StatelessWidget {
  const _DeleteModelButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.settings__deleteModel;

    return AspectRatio(
      aspectRatio: 1,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: label,
          child: ColoredBox(
            color: context.colors.burgundy,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                child: Center(
                  child: Icon(
                    Icons.delete_outline,
                    color: context.colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
