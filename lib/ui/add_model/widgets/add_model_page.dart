import 'package:asr_application/l10n/l10n.dart';
import 'package:asr_application/ui/add_model/view_models/add_model_viewmodel.dart';
import 'package:asr_application/ui/core/widgets/app_banner.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_bar.dart';
import 'add_model_text_field.dart';
import 'download_model_button.dart';
import 'load_model_button.dart';
import 'model_source_separator.dart';

class AddModelPage extends StatelessWidget {
  const AddModelPage({super.key, required this.viewModel});

  final AddModelViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CustomAppBar(title: context.l10n.settings__addModel),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (viewModel.onDownloadModel != null) ...[
                    AddModelTextField(
                      label: context.l10n.addModel__name,
                      hint: 'English v1',
                    ),
                    const SizedBox(height: 20),
                    AddModelTextField(
                      label: context.l10n.addModel__modelLink,
                      hint:
                          'https://huggingface.co/user/repo/resolve/main/model.asrmodel',
                      keyboardType: TextInputType.url,
                      textEditingController: viewModel.modelUriTextController,
                    ),
                    const SizedBox(height: 12),
                    DownloadModelButton(onPressed: viewModel.onDownloadModel!),
                  ],

                  if (viewModel.onPickModel != null) ...[
                    const SizedBox(height: 18),
                    const ModelSourceSeparator(),
                    const SizedBox(height: 18),
                    LoadModelButton(onPickModel: viewModel.onPickModel!),
                  ],

                  const Spacer(),

                  if (viewModel.addModelError != null)
                    WarningBanner(
                      message: context.l10n.errors__filePickerWarning,
                    ),
                  const AppBackButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
