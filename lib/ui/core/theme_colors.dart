import 'package:flutter/material.dart';

class ThemeColors {
  // Primary colors
  Color get white => Color(0xffffffff);
  Color get black => Color(0xff000000);
  Color get blackOpaque => Color(0xa0000000);
  Color get blue => Color(0xff00a6d6);

  // Secondary colors
  Color get darkBlue => Color(0xff0c2340);
  Color get turquoise => Color(0xff00b8c8);
  Color get lightPurple => Color(0xff6f1d77);
  Color get burgundy => Color(0xffa50034);
  Color get yellow => Color(0xffffb81c);
  Color get green => Color(0xff6cc24a);

  // Aliases
  Color get background => white;
  Color get foreground => black;
  Color get foregroundLight => blackOpaque;
}
