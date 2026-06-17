import 'package:flutter/material.dart';

import '../../../app/app_settings_controller.dart';
import '../../../l10n/l10n.dart';
import '../../core/app_settings_scope.dart';
import '../../core/theme.dart';

class SettingsSplitScreenToggle extends StatefulWidget {
  const SettingsSplitScreenToggle({super.key});

  @override
  State<SettingsSplitScreenToggle> createState() =>
      _SettingsSplitScreenToggleState();
}

class _SettingsSplitScreenToggleState extends State<SettingsSplitScreenToggle> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.maybeOf(context);
    final enabled = settings?.splitScreen ?? _enabled;
    final borderColor = enabled ? context.colors.blue : context.colors.black;

    return Semantics(
      button: true,
      toggled: enabled,
      label: context.l10n.settings__splitScreen,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('settings-split-screen-toggle'),
          onTap: () => _setEnabled(!enabled, settings),
          borderRadius: BorderRadius.circular(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.settings__splitScreen,
                    style: TextStyle(
                      color: context.colors.black,
                      fontSize: context.fontSize.body,
                      fontFamily: context.fontFamily.body,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.settings__splitScreenDescription,
                    style: TextStyle(
                      color: context.colors.foregroundLight,
                      fontSize: context.fontSize.small,
                      fontFamily: context.fontFamily.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setEnabled(bool value, AppSettingsController? settings) {
    if (settings == null) {
      setState(() => _enabled = value);
      return;
    }

    settings.setSplitScreen(value);
  }
}
