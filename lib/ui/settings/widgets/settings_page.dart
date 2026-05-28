import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar.dart';
import 'settings_back_button.dart';
import 'settings_save_button.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CustomAppBar(
        title: context.l10n.settings__title,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Spacer(),
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
