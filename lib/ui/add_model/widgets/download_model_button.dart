import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

class DownloadModelButton extends StatelessWidget {
  const DownloadModelButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed ?? () {},
        icon: Icon(Icons.download, color: context.colors.black),
        label: Text(
          context.l10n.addModel__downloadModel,
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
