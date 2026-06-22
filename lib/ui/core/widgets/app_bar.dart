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
  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.actionsDisabled = false,
    this.disabledMessage,
  });

  final String title;
  final List<CustomAppBarAction>? actions;

  /// When true, the menu button is shown greyed out and tapping it surfaces
  /// [disabledMessage] instead of opening the menu. Used to block navigation
  /// away from the recording page while transcription is active.
  final bool actionsDisabled;

  /// Message shown in a snackbar when the menu is tapped while disabled.
  final String? disabledMessage;

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
            child: actionsDisabled
                ? _buildDisabledMenuButton(context)
                : _buildMenuButton(context, menuActions),
          ),
      ],
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    List<CustomAppBarAction> menuActions,
  ) {
    return PopupMenuButton<int>(
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
      child: _menuButtonChild(context),
    );
  }

  Widget _buildDisabledMenuButton(BuildContext context) {
    // The button keeps its normal colours (greying it out would drop below the
    // WCAG text-contrast threshold). Tapping it surfaces a message instead of
    // opening the menu, blocking navigation while recording.
    return Tooltip(
      message: disabledMessage ?? '',
      child: GestureDetector(
        onTap: () {
          final message = disabledMessage;
          if (message == null) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        child: _menuButtonChild(context),
      ),
    );
  }

  Widget _menuButtonChild(BuildContext context) {
    return SizedBox.square(
      child: Material(
        color: context.colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: context.colors.foreground, width: 2),
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
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
