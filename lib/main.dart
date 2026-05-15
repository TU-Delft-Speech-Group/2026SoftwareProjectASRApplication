import 'package:asr_application/ui/core/theme.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DISC - Demo',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(fontFamily: context.fontFamily.arial),
      home: HomePage(viewModel: HomeViewModel()),
    );
  }
}
