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
                Text(
                  recording.content,
                  style: TextStyle(
                    color: context.colors.foreground,
                    fontSize: context.fontSize.body,
                    fontFamily: context.fontFamily.body,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
