import 'package:asr_application/services/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/decoder/decoder_service.dart';
import 'package:asr_application/services/decoder/espnet_decoder_service.dart';
import 'package:asr_application/services/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/pipeline/asr_model_config.dart';
import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/bpe_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'package:asr_application/ui/core/theme.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';

// Select decoding mode at build time:
//   flutter run --dart-define=ASR_DECODER=joint  (default — CTC + attention)
//   flutter run --dart-define=ASR_DECODER=ctc    (CTC-only, faster)
//
// Joint mode is only active when the chosen model has a decoderAsset; if it
// does not, both values fall back to CTC-only automatically.
const _decoderMode = String.fromEnvironment(
  'ASR_DECODER',
  defaultValue: 'joint',
);


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const model = AsrModelConfig.englishGigaspeech;

  final useJoint = _decoderMode == 'joint' && model.decoderAsset != null;
  final decoderService = useJoint
      ? EspnetDecoderService(
          config: EspnetDecoderConfig(
            modelAssetPath: model.decoderAsset!,
            vocab: model.eosId + 1,
            decoderOutputSize: model.decoderOutputSize,
          ),
        )
      : null;
  debugPrint(
    'Decoder mode: ${decoderService != null ? 'joint CTC+attention' : 'CTC-only'}',
  );

  final pipeline = AsrPipelineService(
    encoder: EspnetEncoderService(
      config: EspnetEncoderConfig(modelAssetPath: model.encoderAsset),
    ),
    ctc: EspnetCtcService(
      config: EspnetCtcConfig(modelAssetPath: model.ctcAsset),
    ),
    decoder: decoderService,
  );
  await pipeline.initialize();

  final textService = await _loadTextService(model);
  final streamingService = StreamingTranscriptionService(
    encode: pipeline.encode,
    decoder: DecoderService(
      blankId: model.blankId,
      eosId: model.eosId,
      beamSize: model.beamSize,
    ),
    textService: textService,
  );

  runApp(MainApp(streamingService: streamingService));
}

Future<TokenIdToTextService> _loadTextService(AsrModelConfig model) async {
  try {
    final svc = await BpeTokenIdToTextService.load(
      model.vocabAsset,
      config: model.vocabConfig,
    );
    debugPrint('vocab loaded: BpeTokenIdToTextService ready');
    return svc;
  } catch (e) {
    debugPrint('vocab load failed, falling back to stub: $e');
    return const StubTokenIdToTextService();
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.streamingService});

  final StreamingTranscriptionService streamingService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DISC - Demo',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(fontFamily: context.fontFamily.arial),
      home: HomePage(
        viewModel: HomeViewModel(streamingService: streamingService),
      ),
    );
  }
}
