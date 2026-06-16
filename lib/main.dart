import 'dart:io';

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/active_model_store.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/services/engines/espnet/espnet_asr_engine.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_runtime_controller.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/app/app_settings_controller.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/generated/app_localizations.dart';
import 'utils/result.dart';

const _bundledPackageAsset =
    'assets/EnglishGigaspeechConformerFBank_M01.asrmodel';
const _modelName = 'EnglishGigaspeechConformerFBank_M01';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const storageConfig = LocalModelStorageConfig();
  final localModelService = LocalModelService(config: storageConfig);
  final packageService = ModelPackageService(
    localModelService: localModelService,
    config: storageConfig,
  );
  final modelRepo = ModelRepository(
    localModelService: localModelService,
    config: storageConfig,
  );

  await _ensureInstalled(localModelService, packageService);
  await modelRepo.retrieveModels();

  final activeModelStore = ActiveModelStore();
  final activeModelName = await _resolveActiveModel(
    localModelService: localModelService,
    store: activeModelStore,
  );

  final installController = ModelInstallController(
    packageService: packageService,
    modelRepo: modelRepo,
    initialModelName: activeModelName ?? _modelName,
  );

  const espnetEngine = EspnetAsrEngine();
  Future<AsrRuntime> loadRuntime(String modelName) async {
    debugPrint('Loading ASR runtime for model: $modelName');
    final result = await modelRepo.getModel(modelName);
    if (result is! Ok<Model>) {
      throw StateError('Model $modelName not found after install.');
    }
    final model = result.value;
    // Derive the config from the package manifest when it carries vocab
    // metadata (format version 2+); otherwise fall back to the gigaspeech
    // defaults, which suit legacy (version 1) bundles like the shipped model.
    final config = model.metadata != null
        ? AsrModelConfig.fromMetadata(model.metadata!)
        : AsrAssetModelConfig.englishGigaspeech;
    return espnetEngine.createFromModelFiles(model.files, config);
  }

  final asrController = AsrRuntimeController(loadRuntime: loadRuntime);
  if (activeModelName != null) {
    await asrController.loadModel(activeModelName);
    await activeModelStore.set(activeModelName);
  } else {
    debugPrint('No ASR model installed; UI starts in no-model state.');
  }
  runApp(
    MainApp(asrController: asrController, installController: installController),
  );
}

Future<String?> _resolveActiveModel({
  required LocalModelService localModelService,
  required ActiveModelStore store,
}) async {
  final available = await localModelService.getAvailableModels();
  if (available.isEmpty) return null;
  final persisted = await store.get();
  if (persisted != null && available.contains(persisted)) return persisted;
  return available.first;
}

Future<void> _ensureInstalled(
  LocalModelService localModelService,
  ModelPackageService packageService,
) async {
  final available = await localModelService.getAvailableModels();
  if (available.contains(_modelName)) {
    debugPrint('Model $_modelName already installed, skipping extraction.');
    return;
  }

  final ByteData byteData;
  try {
    byteData = await rootBundle.load(_bundledPackageAsset);
  } on FlutterError catch (e) {
    debugPrint('No bundled ASR model in this build ($e); skipping install.');
    return;
  }

  debugPrint('Installing bundled model $_modelName from asset...');
  final tempDir = await Directory.systemTemp.createTemp('asrmodel_install_');
  try {
    final tempFile = File('${tempDir.path}/bundle.asrmodel');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List());
    await packageService.install(tempFile);
    debugPrint('Model $_modelName installed successfully.');
  } finally {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  }
}

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.asrController,
    this.settingsController,
    this.installController,
    this.homeViewModel,
  });

  final AsrRuntimeController asrController;
  final AppSettingsController? settingsController;
  final HomeViewModel? homeViewModel;

  /// Drives the install workflow when the user picks an .asrmodel file.
  /// When null, the Add Model page hides its load-model button.
  final ModelInstallController? installController;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late HomeViewModel _viewModel;
  late AppSettingsController _settingsController;
  AsrRuntime? _activeRuntime;

  @override
  void initState() {
    super.initState();
    _settingsController = widget.settingsController ?? AppSettingsController();
    _settingsController.addListener(_handleSettingsChanged);

    _activeRuntime = widget.asrController.runtime;
    _viewModel = widget.homeViewModel ?? _createViewModel(_activeRuntime);
    if (widget.homeViewModel == null) {
      widget.asrController.addListener(_handleAsrRuntimeChanged);
    }
  }

  @override
  void dispose() {
    _settingsController.removeListener(_handleSettingsChanged);
    if (widget.settingsController == null) {
      _settingsController.dispose();
    }
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
    if (nextRuntime == null || identical(nextRuntime, _activeRuntime)) return;

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

  Future<Result<void>> _onPickModel() async {
    final controller = widget.installController;
    if (controller == null) return Result.ok(null);
    try {
      final installed = await controller.pickAndInstall();
      if (installed == null) return Result.ok(null);
      if (!mounted) return Result.ok(null);
      await _reloadActiveModel();
      return Result.ok(null);
    } on Exception catch (e) {
      if (!mounted) return Result.ok(null);
      return Result.error(e);
    }
  }

  Future<void> _onModelSelected(String _) async {
    try {
      await _reloadActiveModel();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reloadActiveModel() async {
    final modelName = widget.installController?.activeModelName;
    if (modelName == null) return;
    await widget.asrController.loadModel(modelName);
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      controller: _settingsController,
      child: MaterialApp(
        title: 'DISC - Demo',
        locale: _settingsController.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(fontFamily: context.fontFamily.arial),
        home: HomePage(
          viewModel: _viewModel,
          onPickModel: widget.installController != null ? _onPickModel : null,
          modelController: widget.installController,
          onModelSelected: widget.installController != null
              ? _onModelSelected
              : null,
        ),
      ),
    );
  }
}
