import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';
import '../../add_model/widgets/add_model_page.dart';
import '../../add_model/view_models/add_model_viewmodel.dart';

class AddModelButton extends StatelessWidget {
  const AddModelButton({super.key, this.onPickModel, this.onDownloadModel});

  /// Passed through to the Add Model page so its load-model button can install
  /// a picked .asrmodel. Null hides that button.
  final Future<Result<void>> Function()? onPickModel;
  final Future<Result<void>> Function(String modelUri)? onDownloadModel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddModelPage(
                viewModel: AddModelViewModel(
                  onPickModel: onPickModel,
                  onDownloadModel: onDownloadModel,
                ),
              ),
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
