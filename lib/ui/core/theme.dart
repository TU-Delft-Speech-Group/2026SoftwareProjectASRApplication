import 'package:asr_application/app/app_settings_controller.dart';
import 'package:asr_application/ui/core/theme_colors.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:flutter/widgets.dart';

import 'app_settings_scope.dart';

extension Theme on BuildContext {
  ThemeColors get colors => ThemeColors();
  ThemeFontSize get fontSize {
    final settings = AppSettingsScope.maybeOf(this);
    return ThemeFontSize(body: _bodyFontSize(settings?.fontSize));
  }

  ThemeFontFamily get fontFamily => ThemeFontFamily();

  double _bodyFontSize(AppFontSizeOption? option) {
    return switch (option) {
      AppFontSizeOption.large => 18,
      AppFontSizeOption.xl => 20,
      AppFontSizeOption.medium || null => 16,
    };
  }
}
