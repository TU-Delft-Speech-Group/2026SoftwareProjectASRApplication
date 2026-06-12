import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_bar.dart';
import '../../core/widgets/app_save_button.dart';
import 'add_model_button.dart';
import 'settings_font_size_selector.dart';
import 'settings_language_dropdown.dart';
import 'settings_model_list.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, Future<Result<void>> Function()? onPickModel})
    : _onPickModel = onPickModel;

  /// Passed through to the Add Model page so its load-model button can install
  /// a picked .asrmodel. Null hides that button.
  final Future<Result<void>> Function()? _onPickModel;

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
                    children: [
                      const SettingsFontSizeSelector(),
                      const SizedBox(height: 18),
                      const SettingsLanguageDropdown(),
                      const SizedBox(height: 18),
                      const SettingsModelList(),
                      const SizedBox(height: 18),
                      AddModelButton(onPickModel: _onPickModel),
                    ],
                  ),
                ),
              ),
              const AppSaveButton(),
              const SizedBox(height: 12),
              const AppBackButton(),
            ],
          ),
        ),
      ),
    );
  }
}
