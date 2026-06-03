import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

enum _FontSizeOptionValue { medium, large, xl }

class SettingsFontSizeSelector extends StatefulWidget {
  const SettingsFontSizeSelector({super.key});

  @override
  State<SettingsFontSizeSelector> createState() =>
      _SettingsFontSizeSelectorState();
}

class _SettingsFontSizeSelectorState extends State<SettingsFontSizeSelector> {
  _FontSizeOptionValue _selectedOption = _FontSizeOptionValue.medium;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      label: context.l10n.settings__fontSize,
      child: Row(
        children: [
          Expanded(
            child: _FontSizeOption(
              label: context.l10n.settings__fontSizeMedium,
              selected: _selectedOption == _FontSizeOptionValue.medium,
              onPressed: () => _selectOption(_FontSizeOptionValue.medium),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _FontSizeOption(
              label: context.l10n.settings__fontSizeLarge,
              selected: _selectedOption == _FontSizeOptionValue.large,
              onPressed: () => _selectOption(_FontSizeOptionValue.large),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _FontSizeOption(
              label: context.l10n.settings__fontSizeXl,
              selected: _selectedOption == _FontSizeOptionValue.xl,
              wide: true,
              onPressed: () => _selectOption(_FontSizeOptionValue.xl),
            ),
          ),
        ],
      ),
    );
  }

  void _selectOption(_FontSizeOptionValue option) {
    setState(() => _selectedOption = option);
  }
}

class _FontSizeOption extends StatelessWidget {
  const _FontSizeOption({
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.wide = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final foreground = context.colors.black;

    return SizedBox(
      height: 48,
      child: selected
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.blue,
                foregroundColor: foreground,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: foreground, width: 2),
                ),
              ),
              child: _label,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: foreground,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(color: foreground, width: 2),
              ),
              child: _label,
            ),
    );
  }

  Widget get _label {
    return Builder(
      builder: (context) {
        return Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.black,
            fontSize: wide
                ? context.fontSize.subsubheading
                : context.fontSize.small,
            fontFamily: context.fontFamily.body,
          ),
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.colors.black,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
