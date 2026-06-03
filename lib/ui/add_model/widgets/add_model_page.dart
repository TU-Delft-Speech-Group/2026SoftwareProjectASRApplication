import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_bar.dart';
import '../../core/widgets/app_save_button.dart';

class AddModelPage extends StatelessWidget {
  const AddModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CustomAppBar(title: context.l10n.settings__addModel),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Spacer(),
              AppSaveButton(),
              SizedBox(height: 12),
              AppBackButton(),
            ],
          ),
        ),
      ),
    );
  }
}
