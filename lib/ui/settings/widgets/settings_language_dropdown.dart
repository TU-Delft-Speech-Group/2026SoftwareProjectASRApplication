import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n.dart';
import '../../core/theme.dart';

class SettingsLanguageDropdown extends StatefulWidget {
  const SettingsLanguageDropdown({super.key});

  @override
  State<SettingsLanguageDropdown> createState() =>
      _SettingsLanguageDropdownState();
}

class _SettingsLanguageDropdownState extends State<SettingsLanguageDropdown> {
  Locale? _selectedLocale;

  @override
  Widget build(BuildContext context) {
    final selectedLocale = _selectedLocale ?? _currentSupportedLocale(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settings__language,
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
                child: DropdownButton<Locale>(
                  value: selectedLocale,
                  isExpanded: true,
                  isDense: true,
                  focusColor: Colors.transparent,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: context.colors.black,
                    size: 28,
                  ),
                  items: AppLocalizations.supportedLocales.map((locale) {
                    return DropdownMenuItem(
                      value: locale,
                      child: Text(
                        _languageLabel(context, locale),
                        style: TextStyle(
                          color: context.colors.black,
                          fontSize: context.fontSize.small,
                          fontFamily: context.fontFamily.body,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (locale) {
                    if (locale == null) {
                      return;
                    }

                    setState(() => _selectedLocale = locale);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Locale _currentSupportedLocale(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);

    return AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode == currentLocale.languageCode,
      orElse: () => AppLocalizations.supportedLocales.first,
    );
  }

  String _languageLabel(BuildContext context, Locale locale) {
    return switch (locale.languageCode) {
      'en' => context.l10n.settings__languageEnglish,
      'nl' => context.l10n.settings__languageDutch,
      _ => locale.toLanguageTag(),
    };
  }
}
