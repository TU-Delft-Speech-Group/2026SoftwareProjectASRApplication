import 'package:flutter/material.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/l10n.dart';
import '../../core/app_settings_scope.dart';
import '../../core/theme.dart';

class SettingsFontSizeDropdown extends StatefulWidget {
  const SettingsFontSizeDropdown({super.key});

  @override
  State<SettingsFontSizeDropdown> createState() =>
      _SettingsFontSizeDropdownState();
}

class _SettingsFontSizeDropdownState extends State<SettingsFontSizeDropdown> {
  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.maybeOf(context);
    final selectedOption =
        settings?.getFontsize() ?? SettingsRepository.getDefaultFontsize();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settings__fontSize,
          style: TextStyle(
            color: context.colors.black,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.black, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AppFontSizeOption>(
                  value: selectedOption,
                  isExpanded: true,
                  isDense: true,
                  focusColor: Colors.transparent,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: context.colors.black,
                    size: 28,
                  ),
                  items: AppFontSizeOption.values.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(
                        _label(context, option),
                        style: TextStyle(
                          color: context.colors.black,
                          fontSize: context.fontSize.small,
                          fontFamily: context.fontFamily.body,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (option) async {
                    if (option == null || settings == null) return;
                    await settings.setFontsize(option);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _label(BuildContext context, AppFontSizeOption option) {
    return switch (option) {
      AppFontSizeOption.medium => context.l10n.settings__fontSizeMedium,
      AppFontSizeOption.large => context.l10n.settings__fontSizeLarge,
      AppFontSizeOption.xl => context.l10n.settings__fontSizeXl,
    };
  }
}
