import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

/// Button on the Add Model page that opens a file picker and installs the
/// selected .asrmodel, showing a spinner while the model loads.
class LoadModelButton extends StatefulWidget {
  const LoadModelButton({super.key, required this.onPickModel});

  final Future<void> Function() onPickModel;

  @override
  State<LoadModelButton> createState() => _LoadModelButtonState();
}

class _LoadModelButtonState extends State<LoadModelButton> {
  bool _isLoading = false;

  Future<void> _handleTap() async {
    setState(() => _isLoading = true);
    try {
      await widget.onPickModel();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : _handleTap,
        icon: _isLoading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.colors.black,
                ),
              )
            : Icon(Icons.folder_open_outlined, color: context.colors.black),
        label: Text(
          _isLoading
              ? context.l10n.settings__loadModelLoading
              : context.l10n.settings__loadModel,
          style: TextStyle(
            color: context.colors.black,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: context.colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.colors.black, width: 3),
          ),
        ),
      ),
    );
  }
}
