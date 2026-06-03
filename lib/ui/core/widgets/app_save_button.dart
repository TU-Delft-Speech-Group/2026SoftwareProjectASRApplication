import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../theme.dart';

class AppSaveButton extends StatelessWidget {
  const AppSaveButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed ?? () {},
        icon: Icon(Icons.save, color: context.colors.black),
        label: Text(
          context.l10n.settings__save,
          style: TextStyle(
            color: context.colors.black,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: context.colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.colors.black, width: 3),
          ),
        ),
      ),
    );
  }
}
