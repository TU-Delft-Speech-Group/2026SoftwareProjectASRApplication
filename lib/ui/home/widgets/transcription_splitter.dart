import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/home/widgets/transcriptions_list.dart';
import 'package:flutter/material.dart';

import '../view_models/home_viewmodel.dart';

class TranscriptionSplitter extends StatelessWidget {
  const TranscriptionSplitter({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    double spacing = 32;

    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        SettingsRepository settings = AppSettingsScope.of(context);

        // If no splitscreen, only show the original view
        if (!settings.getSplitscreen()) {
          return TranscriptionsList(viewModel: viewModel);
        }

        // If splitscreen, determine orientation
        final orientation = MediaQuery.of(context).orientation;

        // If portrait, show on top of each other
        if (orientation == Orientation.portrait) {
          return Column(
            spacing: spacing,
            children: [
              Expanded(
                flex: 1,
                child: RotatedBox(
                  quarterTurns: 2,
                  child: TranscriptionsList(viewModel: viewModel),
                ),
              ),
              Divider(),
              Expanded(
                flex: 1,
                child: TranscriptionsList(viewModel: viewModel),
              ),
            ],
          );
        }

        // Else (landscape), show next to each other
        return Row(
          spacing: spacing,
          children: [
            Expanded(
              flex: 1,
              child: RotatedBox(
                quarterTurns: 2,
                child: TranscriptionsList(viewModel: viewModel),
              ),
            ),
            VerticalDivider(),
            Expanded(flex: 1, child: TranscriptionsList(viewModel: viewModel)),
          ],
        );
      },
    );
  }
}
