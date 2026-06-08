import 'package:flutter/material.dart';

import '../../app/app_settings_controller.dart';

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  final AppSettingsController controller;

  static AppSettingsController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
        ?.controller;
  }

  static AppSettingsController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No AppSettingsScope found in context.');
    return controller!;
  }
}
