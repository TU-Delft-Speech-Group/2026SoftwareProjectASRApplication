import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';

import 'package:asr_application/ui/home/widgets/home_screen.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(viewModel: HomeViewModel()),
    );
  }
}
