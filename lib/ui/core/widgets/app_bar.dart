import 'package:asr_application/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class CustomAppBarAction {
  const CustomAppBarAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<CustomAppBarAction>? actions;

  @override
  Widget build(BuildContext context) {
    final menuActions = actions ?? [];

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
      actions: [
        if (menuActions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PopupMenuButton<int>(
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              color: context.colors.white,
              offset: const Offset(8, 16),
              onSelected: (index) => menuActions[index].onPressed(),
              itemBuilder: (context) => [
                for (final (index, action) in menuActions.indexed)
                  PopupMenuItem(
                    value: index,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (action.icon != null) ...[
                          Icon(action.icon, color: context.colors.foreground),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          action.label,
                          style: TextStyle(
                            color: context.colors.foreground,
                            fontSize: context.fontSize.body,
                            fontFamily: context.fontFamily.body,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              child: SizedBox.square(
                child: Material(
                  color: context.colors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: context.colors.foreground,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsetsGeometry.all(12),
                    child: Row(
                      spacing: 12,
                      children: [
                        Text(context.l10n.menu__title),
                        Icon(Icons.menu, color: context.colors.foreground),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
