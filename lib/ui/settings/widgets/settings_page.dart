import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar.dart';
import 'settings_back_button.dart';
import 'settings_font_size_selector.dart';
import 'settings_language_dropdown.dart';
import 'settings_model_list.dart';
import 'settings_save_button.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
            children: const [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsFontSizeSelector(),
                      SizedBox(height: 18),
                      SettingsLanguageDropdown(),
                      SizedBox(height: 18),
                      SettingsModelList(),
                    ],
                  ),
                ),
              ),
              SettingsSaveButton(),
              SizedBox(height: 12),
              SettingsBackButton(),
            ],
          ),
        ),
      ),
    );
  }
}
