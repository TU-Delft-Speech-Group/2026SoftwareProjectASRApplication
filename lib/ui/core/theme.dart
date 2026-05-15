import 'package:asr_application/ui/core/theme_colors.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:flutter/widgets.dart';

extension Theme on BuildContext {
  ThemeColors get colors => ThemeColors();
  ThemeFontSize get fontSize => ThemeFontSize();
  ThemeFontFamily get fontFamily => ThemeFontFamily();
}
