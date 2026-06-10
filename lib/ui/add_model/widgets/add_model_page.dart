import 'package:asr_application/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_bar.dart';
import 'add_model_text_field.dart';
import 'download_model_button.dart';
import 'load_model_button.dart';
import 'model_source_separator.dart';

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
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AddModelTextField(
                label: context.l10n.addModel__name,
                hint: 'English v1',
              ),
              const SizedBox(height: 20),
              AddModelTextField(
                label: context.l10n.addModel__modelLink,
                hint: 'https://huggingface.co/user/model',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              const DownloadModelButton(),
              if (pickModel != null) ...[
                const SizedBox(height: 18),
                const ModelSourceSeparator(),
                const SizedBox(height: 18),
                LoadModelButton(onPickModel: pickModel),
              ],
              const Spacer(),
              const AppBackButton(),
            ],
          ),
        ),
      ),
    );
  }
}
