import 'package:flutter/material.dart';

import '../theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      clipBehavior: Clip.none,
      title: Text(
        title,
        style: TextStyle(
          fontSize: context.fontSize.heading,
          fontFamily: context.fontFamily.heading,
        ),
      ),

      foregroundColor: context.colors.black,
      backgroundColor: context.colors.blue,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
