import 'package:asr_application/services/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/decoder/decoder_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const model = AsrModelConfig.englishGigaspeech;

  final pipeline = AsrPipelineService(
    encoder: EspnetEncoderService(
      config: EspnetEncoderConfig(modelAssetPath: model.encoderAsset),
    ),
    ctc: EspnetCtcService(
      config: EspnetCtcConfig(modelAssetPath: model.ctcAsset),
    ),
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
