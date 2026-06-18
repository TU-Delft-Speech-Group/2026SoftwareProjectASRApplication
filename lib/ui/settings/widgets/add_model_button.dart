import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../../add_model/widgets/add_model_page.dart';

class AddModelButton extends StatelessWidget {
  const AddModelButton({super.key, required this.modelInstallController});

  /// Passed through to the Add Model page so its load-model button can install
  /// a picked .asrmodel. Null hides that button.
  final ModelInstallController modelInstallController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  AddModelPage(installModelController: modelInstallController),
            ),
          );
        },
        icon: Icon(Icons.add_circle, color: context.colors.black),
        label: Text(
          context.l10n.settings__addModel,
          style: TextStyle(
            color: context.colors.black,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          side: BorderSide(color: context.colors.black, width: 3),
        ),
      ),
    );
  }
}
