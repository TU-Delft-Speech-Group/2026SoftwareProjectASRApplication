import 'package:asr_application/ui/core/theme.dart';
import 'package:asr_application/ui/core/widgets/app_banner.dart';
import 'package:asr_application/ui/core/widgets/fixed_width_container.dart';
import 'package:asr_application/ui/home/widgets/transcriptions_list.dart';
import 'package:asr_application/ui/settings/widgets/settings_page.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/widgets/app_bar.dart';
import '../view_models/home_viewmodel.dart';
import 'recording_button.dart';
import 'settings_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.viewModel,
    this.onPickModel,
  });

  final HomeViewModel viewModel;

  /// Passed through Settings to the Add Model page, where the load-model
  /// button lives. Null hides that button.
  final Future<void> Function()? onPickModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CustomAppBar(
        title: context.l10n.home__title,
        actions: [
          SettingsButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(onPickModel: onPickModel),
                ),
              );
            },
          ),
        ],
      ),

      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          return FixedWidthContainer(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: TranscriptionsList(viewModel: viewModel),
                  ),
                ),
              ),

              if (viewModel.recordingError != null)
                ErrorBanner(
                  message: context.l10n.errors__transcribing,
                  onPressed: viewModel.toggleTranscribing,
                ),

              if (viewModel.isUsingVocabFallback)
                WarningBanner(message: context.l10n.errors__vocabFallbackWarning),

              RecordingButton(viewModel: viewModel),
            ],
          );
        },
      ),
    );
  }
}
