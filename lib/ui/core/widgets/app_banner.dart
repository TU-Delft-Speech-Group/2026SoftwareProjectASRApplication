import 'package:flutter/material.dart';

import '../theme.dart';

class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.iconSemanticLabel,
    this.onPressed,
    this.liveRegion = false,
  });

  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? iconSemanticLabel;
  final VoidCallback? onPressed;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        Icon(
          icon,
          color: foregroundColor,
          size: context.fontSize.body,
          semanticLabel: iconSemanticLabel,
        ),
        Flexible(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foregroundColor,
              fontSize: context.fontSize.body,
              fontFamily: context.fontFamily.body,
            ),
          ),
        ),
      ],
    );

    final Widget banner;
    if (onPressed != null) {
      banner = SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: content,
        ),
      );
    } else {
      banner = Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: content,
      );
    }

    if (liveRegion) {
      return Semantics(liveRegion: true, child: banner);
    }
    return banner;
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onPressed});

  final String message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AppBanner(
    message: message,
    icon: Icons.error_rounded,
    backgroundColor: context.colors.burgundy,
    foregroundColor: context.colors.white,
    onPressed: onPressed,
    liveRegion: true,
  );
}

class SuccessBanner extends StatelessWidget {
  const SuccessBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => AppBanner(
    message: message,
    icon: Icons.check_circle_rounded,
    backgroundColor: context.colors.green,
    foregroundColor: context.colors.black,
    iconSemanticLabel: 'Success',
    liveRegion: true,
  );
}

class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => AppBanner(
    message: message,
    icon: Icons.warning_rounded,
    backgroundColor: context.colors.yellow,
    foregroundColor: context.colors.black,
    iconSemanticLabel: 'Warning',
  );
}
