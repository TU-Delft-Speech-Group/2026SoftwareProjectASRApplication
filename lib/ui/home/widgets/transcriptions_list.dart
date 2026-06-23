import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../view_models/home_viewmodel.dart';

class TranscriptionsList extends StatelessWidget {
  const TranscriptionsList({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        if (viewModel.recentTranscriptions.isEmpty) {
          return Text(
            context.l10n.home__emptyFallback,
            style: TextStyle(
              color: context.colors.foreground,
              fontSize: context.fontSize.body,
              fontFamily: context.fontFamily.body,
            ),
          );
        }

        return ListView.separated(
          reverse: true,
          shrinkWrap: true,
          itemCount: min(viewModel.recentTranscriptions.length, 10),
          separatorBuilder: (context, index) => SizedBox(height: 32),

          itemBuilder: (context, index) {
            final reversedIndex =
                viewModel.recentTranscriptions.length - 1 - index;
            RecordingTranscription recording =
                viewModel.recentTranscriptions[reversedIndex];
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  recording.label,
                  style: TextStyle(
                    color: context.colors.foregroundLight,
                    fontFamily: context.fontFamily.body,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                _TranscriptionText(recording: recording),
              ],
            );
          },
        );
      },
    );
  }
}

// Renders the confirmed content solid and the unconfirmed tail muted. Falls back
// to a plain Text when there is no tail so the common case stays simple.
class _TranscriptionText extends StatelessWidget {
  const _TranscriptionText({required this.recording});

  final RecordingTranscription recording;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: context.colors.foreground,
      fontSize: context.fontSize.body,
      fontFamily: context.fontFamily.body,
    );

    if (recording.tentativeContent.isEmpty) {
      return Text(recording.content, style: baseStyle);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: recording.content),
          TextSpan(
            text: recording.tentativeContent,
            style: TextStyle(
              color: context.colors.foregroundTentative,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      style: baseStyle,
    );
  }
}
