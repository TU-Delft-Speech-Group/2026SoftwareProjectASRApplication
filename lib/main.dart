import 'dart:io';

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/config/remote_model_service.dart';
import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/data/services/remote/remote_model_service.dart';
import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/services/engines/asr_engine_registry.dart';
import 'package:asr_application/services/engines/espnet/espnet_asr_engine.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/services/pipeline/asr_runtime_controller.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:asr_application/utils/decide_active_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/generated/app_localizations.dart';
import 'utils/result.dart';

const _bundledPackageAsset =
    'assets/EnglishGigaspeechConformerFBank_M01.asrmodel';
const _bundledModelName = 'EnglishGigaspeechConformerFBank_M01';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const storageConfig = LocalModelStorageConfig();
  final localModelService = LocalModelService(config: storageConfig);
  final remoteModelService = await RemoteModelService.create(
    config: RemoteModelServiceConfig(),
  );
  final packageService = ModelPackageService(
    localModelService: localModelService,
    config: storageConfig,
  );
  final modelRepo = ModelRepository(
    localModelService: localModelService,
    config: storageConfig,
  );

  final sharedPreferences = SharedPreferencesAsync();
  final preferences = await sharedPreferences.getAll();
  preferences.removeWhere((str, obj) => obj.runtimeType != String);
  final preferencesFiltered = preferences.cast<String, String>();
  final settingsRepository = SettingsRepository(
    save: sharedPreferences.setString,
    remove: sharedPreferences.remove,
    preferences: preferencesFiltered,
  );

  await _installBundledModelIfAvailable(localModelService, packageService);
  await modelRepo.retrieveModels();

  // Ensure model selection still reflects available models on startup
  final availableModels = modelRepo.getModelList();
  final currentModelName = settingsRepository.getModelName();
  await settingsRepository.setModelName(
    decideActiveModel(availableModels, currentModelName),
  );

  final engineRegistry = AsrEngineRegistry(engines: const [EspnetAsrEngine()]);
  Future<AsrRuntime> loadRuntime(String modelName) async {
    debugPrint('Loading ASR runtime for model: $modelName');
    final result = await modelRepo.getModel(modelName);
    if (result is! Ok<Model>) {
      throw StateError('Model $modelName not found after install.');
    }
    final model = result.value;
    return engineRegistry.createRuntime(model);
  }

  final asrController = AsrRuntimeController(loadRuntime: loadRuntime);
  final installController = ModelInstallController(
    packageService: packageService,
    remoteService: remoteModelService,
    modelRepo: modelRepo,
    settingsRepository: settingsRepository,
    onActiveModelRenamed: asrController.renameActiveModel,
  );

  if (installController.activeModelName != null) {
    await asrController.loadModel(installController.activeModelName!);
  } else {
    debugPrint('No ASR model installed; UI starts in no-model state.');
  }

  runApp(
    MainApp(
      asrController: asrController,
      installController: installController,
      settingsRepository: settingsRepository,
    ),
  );
}

Future<void> _installBundledModelIfAvailable(
  LocalModelService localModelService,
  ModelPackageService packageService,
) async {
  final available = await localModelService.getAvailableModels();
  if (available.contains(_bundledModelName)) {
    debugPrint(
      'Model $_bundledModelName already installed, skipping extraction.',
    );
    return;
  }

  final ByteData byteData;
  try {
    byteData = await rootBundle.load(_bundledPackageAsset);
  } on FlutterError catch (e) {
    debugPrint('No bundled ASR model in this build ($e); skipping install.');
    return;
  }

  debugPrint('Installing bundled model $_bundledModelName from asset...');
  final tempDir = await Directory.systemTemp.createTemp('asrmodel_install_');
  try {
    final tempFile = File('${tempDir.path}/bundle.asrmodel');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List());
    await packageService.install(tempFile);
    debugPrint('Model $_bundledModelName installed successfully.');
  } finally {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  }
}

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.asrController,
    required this.settingsRepository,
    required this.installController,
    this.homeViewModel,
  });

  final AsrRuntimeController asrController;
  final SettingsRepository settingsRepository;
  final HomeViewModel? homeViewModel;

  /// Drives the install workflow when the user picks an .asrmodel file.
  /// When null, the Add Model page hides its load-model button.
  final ModelInstallController installController;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late HomeViewModel _viewModel;
  late SettingsRepository _settingsRepository;
  AsrRuntime? _activeRuntime;

  @override
  void initState() {
    super.initState();
    _settingsRepository = widget.settingsRepository;
    _settingsRepository.addListener(_handleSettingsChanged);

    _activeRuntime = widget.asrController.runtime;
    _viewModel = widget.homeViewModel ?? _createViewModel(_activeRuntime);
    if (widget.homeViewModel == null) {
      widget.asrController.addListener(_handleAsrRuntimeChanged);
    }
  }

  @override
  void dispose() {
    _settingsRepository.removeListener(_handleSettingsChanged);
    widget.asrController.removeListener(_handleAsrRuntimeChanged);
    if (widget.homeViewModel == null) {
      _viewModel.dispose();
    }
    widget.asrController.dispose();
    super.dispose();
  }

  HomeViewModel _createViewModel(AsrRuntime? runtime) {
    if (runtime == null) {
      return HomeViewModel(hasActiveModel: false);
    }
    return HomeViewModel(
      streamingService: runtime.transcriptionService,
      vadService: runtime.vadService,
    );
  }

  void _handleAsrRuntimeChanged() {
    // Only handle runtime changes if we're managing the ViewModel
    if (widget.homeViewModel != null) {
      return;
    }

    final nextRuntime = widget.asrController.runtime;
    // React even when nextRuntime is null: deleting the last installed model
    // clears the runtime, and the UI needs to fall back to the no-model state.
    if (identical(nextRuntime, _activeRuntime)) return;

    final previousViewModel = _viewModel;
    setState(() {
      _activeRuntime = nextRuntime;
      _viewModel = _createViewModel(nextRuntime);
    });
    previousViewModel.dispose();
  }

  void _handleSettingsChanged() {
    setState(() {});
  }

  Future<Result<void>> _onModelSelected(String _) async {
    try {
      await _reloadActiveModel();
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  Future<void> _onModelDeleted() async => await _reloadActiveModel();

  Future<void> _reloadActiveModel() async {
    final modelName = widget.installController.activeModelName;
    if (modelName == null) {
      await widget.asrController.close();
      return;
    } else {
      await widget.asrController.loadModel(modelName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: _settingsRepository,
      child: MaterialApp(
        title: 'DISC - Demo',
        locale: _settingsRepository.getLocale(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(fontFamily: context.fontFamily.arial),
        home: HomePage(
          viewModel: _viewModel,
          modelController: widget.installController,
          onModelSelected: _onModelSelected,
          onModelDeleted: _onModelDeleted,
        ),
      ),
    );
  }
}
