import 'package:flutter/material.dart';

import '../theme.dart';

class AppNavigationButton extends StatelessWidget {
  const AppNavigationButton({
    super.key,
    required this.label,
    required this.builder,
    this.icon,
    this.alignment = Alignment.centerLeft,
  });

  final WidgetBuilder builder;
  final String label;
  final IconData? icon;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: builder));
        },
        icon: icon != null
            ? Icon(icon, color: context.colors.foreground)
            : null,
        label: Text(
          label,
          style: TextStyle(
            color: context.colors.foreground,
            fontSize: context.fontSize.body,
            fontFamily: context.fontFamily.body,
          ),
        ),
        style: OutlinedButton.styleFrom(
          alignment: alignment,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: context.colors.black, width: 3),
        ),
      ),
    );
  }
}
