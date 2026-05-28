import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_runtime.dart';
import 'package:asr_application/ui/core/theme.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final asrController = AsrRuntimeController();
  await asrController.loadModel(AsrModelConfig.englishGigaspeech);
  runApp(MainApp(asrController: asrController));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, required this.asrController});

  final AsrRuntimeController asrController;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late HomeViewModel _viewModel;
  AsrRuntime? _activeRuntime;

  @override
  void initState() {
    super.initState();
    final runtime = widget.asrController.runtime!;
    _activeRuntime = runtime;
    _viewModel = _createViewModel(runtime);
    widget.asrController.addListener(_handleAsrRuntimeChanged);
  }

  @override
  void dispose() {
    widget.asrController.removeListener(_handleAsrRuntimeChanged);
    _viewModel.dispose();
    widget.asrController.dispose();
    super.dispose();
  }

  HomeViewModel _createViewModel(AsrRuntime runtime) {
    return HomeViewModel(streamingService: runtime.streamingService);
  }

  void _handleAsrRuntimeChanged() {
    final nextRuntime = widget.asrController.runtime;
    if (nextRuntime == null || identical(nextRuntime, _activeRuntime)) {
      return;
    }

    final previousViewModel = _viewModel;
    setState(() {
      _activeRuntime = nextRuntime;
      _viewModel = _createViewModel(nextRuntime);
    });
    previousViewModel.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DISC - Demo',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(fontFamily: context.fontFamily.arial),
      home: HomePage(viewModel: _viewModel),
    );
  }
}
