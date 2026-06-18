import 'package:asr_application/l10n/l10n.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/ui/core/widgets/app_banner.dart';
import 'package:asr_application/utils/error_message.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_bar.dart';
import 'add_model_text_field.dart';
import 'download_model_button.dart';
import 'load_model_button.dart';
import 'model_source_separator.dart';

class AddModelPage extends StatefulWidget {
  final ModelInstallController installModelController;
  const AddModelPage({super.key, required this.installModelController});

  @override
  State<StatefulWidget> createState() => _AddModelPageState();
}

class _AddModelPageState extends State<AddModelPage> {
  late TextEditingController _textEditingController;

  ErrorMessage? _errorMessage;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
    widget.installModelController.addListener(_handleStateChange);
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    widget.installModelController.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _wrapHandler(Future<Result<void>> Function() handler) async {
    Result<void> result = await handler();
    switch (result) {
      case Ok():
        setState(() => _errorMessage = null);
        return;
      case Error():
        setState(
          () => _errorMessage = ErrorMessage(message: result.error.toString()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 18),
              AddModelTextField(
                label: context.l10n.addModel__modelLink,
                hint:
                    'https://huggingface.co/user/repo/resolve/main/model.asrmodel',
                keyboardType: TextInputType.url,
                textEditingController: _textEditingController,
              ),
              const SizedBox(height: 12),
              DownloadModelButton(
                onPressed: widget.installModelController.installStatus == .idle
                    ? () => _wrapHandler(
                        () => widget.installModelController.downloadAndInstall(
                          _textEditingController.text,
                        ),
                      )
                    : null,
              ),

              const SizedBox(height: 18),
              const ModelSourceSeparator(),
              const SizedBox(height: 18),
              LoadModelButton(
                onPressed: widget.installModelController.installStatus == .idle
                    ? () => _wrapHandler(
                        widget.installModelController.pickAndInstall,
                      )
                    : null,
              ),

              const Spacer(),

              if (_errorMessage != null) ...[
                WarningBanner(message: context.l10n.errors__addModelError),
                const SizedBox(height: 12),
              ],

              if (widget.installModelController.installStatus != .idle) ...[
                AppBanner(
                  message:
                      switch (widget.installModelController.installStatus) {
                        .downloadAndInstall =>
                          context.l10n.addModel__downloadModelLoading,
                        _ => context.l10n.addModel__loadModelLoading,
                      },
                  icon: Icons.hourglass_bottom,
                  backgroundColor: context.colors.turquoise,
                  foregroundColor: context.colors.foreground,
                ),
                const SizedBox(height: 12),
              ],

              const AppBackButton(),
            ],
          ),
        ),
      ),
    );
  }
}
