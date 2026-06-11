import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../view_models/home_viewmodel.dart';

class RecordingButton extends StatelessWidget {
  const RecordingButton({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final isTranscribing = viewModel.isTranscribing;
        final foreground = isTranscribing
            ? context.colors.black
            : context.colors.white;

        if (!viewModel.hasActiveModel) {
          return Center(
            child: Text(
              context.l10n.home__noModelSelected,
              style: TextStyle(
                color: context.colors.burgundy,
                fontSize: context.fontSize.subsubheading,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (viewModel.hasRecordingPermissions == false) {
          return Center(
            child: Text(
              context.l10n.home__recordingPermission,
              style: TextStyle(
                color: context.colors.burgundy,
                fontSize: context.fontSize.subsubheading,
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 8), // bottom shadow
              ),
            ],
          ),
          child: FilledButton.icon(
            autofocus: true,
            onPressed: viewModel.toggleTranscribing,
            icon: Icon(
              isTranscribing ? Icons.stop_rounded : Icons.mic,
              size: context.fontSize.subheading,
              color: foreground,
            ),
            label: Text(
              isTranscribing
                  ? context.l10n.home__stopRecording
                  : context.l10n.home__startRecording,
              style: TextStyle(
                color: foreground,
                fontSize: context.fontSize.subheading,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: isTranscribing
                  ? context.colors.yellow
                  : context.colors.burgundy,
              side: BorderSide(color: foreground, width: 4),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
          ),
        );
      },
    );
  }
}
