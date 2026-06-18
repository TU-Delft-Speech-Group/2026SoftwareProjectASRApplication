import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

/// Button on the Add Model page that opens a file picker and installs the
/// selected .asrmodel, showing a spinner while the model loads.
class LoadModelButton extends StatelessWidget {
  const LoadModelButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.folder_open_outlined, color: context.colors.black),
        label: Text(
          context.l10n.addModel__loadModel,
          style: TextStyle(
            color: context.colors.black,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: context.colors.white,
          disabledBackgroundColor: context.colors.blackOpaque,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.colors.black, width: 3),
          ),
        ),
      ),
    );
  }
}
