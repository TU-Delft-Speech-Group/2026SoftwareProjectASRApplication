import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_bar.dart';
import '../../core/widgets/app_save_button.dart';
import 'load_model_button.dart';

class AddModelPage extends StatelessWidget {
  const AddModelPage({super.key, this.onPickModel});

  /// Opens a file picker and installs the selected .asrmodel. Null hides the
  /// load-model button.
  final Future<void> Function()? onPickModel;

  @override
  Widget build(BuildContext context) {
    final pickModel = onPickModel;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CustomAppBar(title: context.l10n.settings__addModel),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              if (pickModel != null) ...[
                LoadModelButton(onPickModel: pickModel),
                const SizedBox(height: 12),
              ],
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
