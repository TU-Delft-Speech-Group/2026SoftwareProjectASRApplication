import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
