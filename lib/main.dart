import 'dart:io';

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/domain/models/model/model_files.dart';
import 'package:asr_application/services/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/decoder/decoder_service.dart';
import 'package:asr_application/services/decoder/espnet_decoder_service.dart';
import 'package:asr_application/services/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/bpe_token_id_to_text_service.dart';
import 'package:asr_application/app/app_settings_controller.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/generated/app_localizations.dart';
import 'utils/result.dart';

// Select decoding mode at build time:
//   flutter run --dart-define=ASR_DECODER=joint  (default — CTC + attention)
//   flutter run --dart-define=ASR_DECODER=ctc    (CTC-only, faster)
//
// Joint mode is only active when the model has a decoder; if it does not,
// both values fall back to CTC-only automatically.
const _decoderMode = String.fromEnvironment(
  'ASR_DECODER',
  defaultValue: 'joint',
);

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

  final installController = ModelInstallController(
    packageService: packageService,
    modelRepo: modelRepo,
    initialModelName: _modelName,
  );

  Future<AsrRuntime> loadRuntime(AsrModelConfig config) async {
    final name = installController.activeModelName;
    debugPrint('Loading ASR runtime for model: $name');
    final result = await modelRepo.getModel(name);
    if (result is! Ok<Model>) {
      throw StateError('Model $name not found after install.');
    }
    return _buildRuntime(result.value.files, config);
  }

  final asrController = AsrRuntimeController(loadRuntime: loadRuntime);
  await asrController.loadModel(AsrModelConfig.englishGigaspeech);
  runApp(
    MainApp(asrController: asrController, installController: installController),
  );
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

  debugPrint('Installing bundled model $_modelName from asset...');
  final byteData = await rootBundle.load(_bundledPackageAsset);
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

Future<AsrRuntime> _buildRuntime(
  ModelFiles modelFiles,
  AsrModelConfig config,
) async {
  final useJoint = _decoderMode == 'joint' && modelFiles.decoderPath != null;
  final decoder = useJoint
      ? EspnetDecoderService(
          config: EspnetDecoderConfig(
            modelFilePath: modelFiles.decoderPath!.path,
            vocab: config.eosId + 1,
            decoderOutputSize: config.decoderOutputSize,
          ),
        )
      : null;

  debugPrint(
    'Decoder mode: ${decoder != null ? 'joint CTC+attention' : 'CTC-only'}',
  );

  debugPrint(
    'Initializing ASR pipeline with encoder at ${modelFiles.encoderPath.path}, '
    'CTC at ${modelFiles.ctcPath.path}, '
    'and decoder at ${decoder != null ? modelFiles.decoderPath!.path : 'N/A'}',
  );

  final pipeline = AsrPipelineService(
    encoder: EspnetEncoderService(
      config: EspnetEncoderConfig(modelFilePath: modelFiles.encoderPath.path),
    ),
    ctc: EspnetCtcService(
      config: EspnetCtcConfig(modelFilePath: modelFiles.ctcPath.path),
    ),
    decoder: decoder,
  );

  try {
    await pipeline.initialize();
  } catch (error, stackTrace) {
    await pipeline.dispose();
    throw AsrInitializationException(
      stage: 'model loading',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  final raw = await modelFiles.vocabPath.readAsString();
  final vocab = raw.split('\n').where((line) => line.isNotEmpty).toList();
  final textService = BpeTokenIdToTextService.fromVocab(
    vocab,
    config: config.vocabConfig,
  );
  debugPrint('vocab loaded: BpeTokenIdToTextService ready');

  return AsrRuntime(
    pipeline: pipeline,
    streamingService: StreamingTranscriptionService(
      encode: pipeline.encode,
      decoder: DecoderService(
        blankId: config.blankId,
        eosId: config.eosId,
        beamSize: config.beamSize,
      ),
      textService: textService,
    ),
  );
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

    final runtime = widget.asrController.runtime!;
    _activeRuntime = runtime;
    _viewModel = widget.homeViewModel ?? _createViewModel(runtime);
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

  HomeViewModel _createViewModel(AsrRuntime runtime) {
    return HomeViewModel(streamingService: runtime.streamingService);
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

  Future<void> _onPickModel() async {
    final controller = widget.installController;
    if (controller == null) return;
    try {
      final installed = await controller.pickAndInstall();
      if (installed == null) return;
      if (!mounted) return;
      // TODO: derive AsrModelConfig from the picked model's manifest so
      // other recipes (different decoder hidden size, blank/eos ids,
      // vocab config) work too. Today this only fits gigaspeech-recipe
      // models (M01, M01Libri100).
      await widget.asrController.loadModel(AsrModelConfig.englishGigaspeech);
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
        ),
      ),
    );
  }
}
