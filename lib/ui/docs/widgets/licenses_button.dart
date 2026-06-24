import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

class LicensesButton extends StatelessWidget {
  const LicensesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final info = await PackageInfo.fromPlatform();
          if (!context.mounted) return;

          showLicensePage(
            context: context,
            applicationName: info.appName,
            applicationVersion: info.version,
            applicationIcon: Image.asset("assets/icons/disc_rounded.png"),
          );
        },
        icon: Icon(
          Icons.document_scanner_outlined,
          color: context.colors.black,
        ),
        label: Text(
          context.l10n.docs__licensesTitle,
          style: TextStyle(
            color: context.colors.black,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: context.colors.black, width: 3),
        ),
      ),
    );
  }
}
