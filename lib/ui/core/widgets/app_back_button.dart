import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../theme.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed ?? () => Navigator.of(context).pop(),
        icon: Icon(Icons.arrow_back, color: context.colors.black),
        label: Text(
          context.l10n.settings__back,
          style: TextStyle(
            color: context.colors.black,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: context.colors.black, width: 3),
        ),
      ),
    );
  }
}
