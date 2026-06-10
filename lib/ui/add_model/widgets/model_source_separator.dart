import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

class ModelSourceSeparator extends StatelessWidget {
  const ModelSourceSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.addModel__sourceSeparator,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: context.colors.black,
        fontSize: context.fontSize.body,
        fontFamily: context.fontFamily.body,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
