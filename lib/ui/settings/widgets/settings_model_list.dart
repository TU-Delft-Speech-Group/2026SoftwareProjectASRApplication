import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

enum _ModelOption { user1, user2 }

class SettingsModelList extends StatefulWidget {
  const SettingsModelList({super.key});

  @override
  State<SettingsModelList> createState() => _SettingsModelListState();
}

class _SettingsModelListState extends State<SettingsModelList> {
  _ModelOption _selectedModel = _ModelOption.user2;

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
        _ModelCard(
          id: 'user1',
          name: context.l10n.settings__modelUser1,
          version: context.l10n.settings__modelUser1Version,
          storage: context.l10n.settings__modelStorage,
          selected: _selectedModel == _ModelOption.user1,
          onPressed: () => _selectModel(_ModelOption.user1),
        ),
        const SizedBox(height: 8),
        _ModelCard(
          id: 'user2',
          name: context.l10n.settings__modelUser2,
          version: context.l10n.settings__modelUser2Version,
          storage: context.l10n.settings__modelStorage,
          selected: _selectedModel == _ModelOption.user2,
          onPressed: () => _selectModel(_ModelOption.user2),
        ),
      ],
    );
  }

  void _selectModel(_ModelOption model) {
    setState(() => _selectedModel = model);
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.id,
    required this.name,
    required this.version,
    required this.storage,
    required this.onPressed,
    this.selected = false,
  });

  final String id;
  final String name;
  final String version;
  final String storage;
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
        child: SizedBox(
          height: 80,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: context.colors.black,
                            fontSize: context.fontSize.body,
                            fontFamily: context.fontFamily.body,
                          ),
                        ),
                        Text(
                          version,
                          style: TextStyle(
                            color: context.colors.black,
                            fontSize: context.fontSize.small,
                            fontFamily: context.fontFamily.body,
                          ),
                        ),
                        Text(
                          storage,
                          style: TextStyle(
                            color: context.colors.black,
                            fontSize: context.fontSize.small,
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
