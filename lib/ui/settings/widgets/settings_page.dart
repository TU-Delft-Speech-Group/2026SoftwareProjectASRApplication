import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../services/model_install/model_install_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_bar.dart';
import 'add_model_button.dart';
import 'settings_font_size_selector.dart';
import 'settings_language_dropdown.dart';
import 'settings_model_list.dart';
import 'settings_split_screen_toggle.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.onPickModel,
    this.onDownloadModel,
    this.modelController,
    this.onModelSelected,
  });

  /// Passed through to the Add Model page so its load-model button can install
  /// a picked .asrmodel. Null hides that button.
  final Future<Result<void>> Function()? onPickModel;
  final Future<Result<void>> Function(String modelUri)? onDownloadModel;
  final ModelInstallController? modelController;
  final Future<void> Function(String modelName)? onModelSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CustomAppBar(title: context.l10n.settings__title),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 18,
                    children: [
                      const SettingsSplitScreenToggle(),
                      const SettingsFontSizeSelector(),
                      const SettingsLanguageDropdown(),
                      SettingsModelList(
                        modelController: modelController,
                        onModelSelected: onModelSelected,
                      ),
                      const SizedBox(height: 18),
                      AddModelButton(
                        onPickModel: onPickModel,
                        onDownloadModel: onDownloadModel,
                      ),
                    ],
                  ),
                ),
              ),
              const AppBackButton(),
            ],
          ),
        ),
      ),
    );
  }
}
