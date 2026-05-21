import 'package:asr_application/services/token_decoder/bpe_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/vocab_config.dart';
import 'package:asr_application/ui/core/theme.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final textService = await _loadTextService();
  runApp(MainApp(textService: textService));
}

/* loads BpeTokenIdToTextService when the vocab asset is present;
   falls back to the stub so the app still runs without the file
*/
Future<TokenIdToTextService> _loadTextService() async {
  try {
    final svc = await BpeTokenIdToTextService.load(
      'assets/models/english/vocab.txt',
      config: VocabConfig.english,
    );
    debugPrint('vocab loaded: BpeTokenIdToTextService ready');
    return svc;
  } catch (e) {
    debugPrint('vocab load failed, falling back to stub: $e');
    return const StubTokenIdToTextService();
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.textService});

  final TokenIdToTextService textService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DISC - Demo',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(fontFamily: context.fontFamily.arial),
      home: HomePage(viewModel: HomeViewModel(textService: textService)),
    );
  }
}
