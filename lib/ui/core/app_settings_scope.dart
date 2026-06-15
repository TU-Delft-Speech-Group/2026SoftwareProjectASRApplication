import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:flutter/material.dart';

class AppSettingsScope extends InheritedNotifier<SettingsRepository> {
  const AppSettingsScope({
    super.key,
    required this.settings,
    required super.child,
  }) : super(notifier: settings);

  final SettingsRepository settings;

  static SettingsRepository? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
        ?.settings;
  }

  static SettingsRepository of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No AppSettingsScope found in context.');
    return controller!;
  }
}
