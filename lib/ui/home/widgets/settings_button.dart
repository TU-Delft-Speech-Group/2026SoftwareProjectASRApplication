import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: SizedBox.square(
        dimension: 50,
        child: Material(
          color: context.colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: context.colors.black, width: 2),
          ),
          child: IconButton(
            tooltip: context.l10n.settings__title,
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            icon: Icon(Icons.settings, color: context.colors.black, size: 24),
          ),
        ),
      ),
    );
  }
}
