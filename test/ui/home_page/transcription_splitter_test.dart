import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/transcription_splitter.dart';
import 'package:asr_application/ui/home/widgets/transcriptions_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSplitter(
    WidgetTester tester, {
    required bool splitScreen,
    required Size surfaceSize,
    required HomeViewModel viewModel,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      AppSettingsScope(
        settings: SettingsRepository(
          save: (String key, String value) async {},
          preferences: {'settings_splitscreen': splitScreen.toString()},
        ),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(fontFamily: ThemeFontFamily().arial),
          home: MediaQuery(
            data: MediaQueryData(size: surfaceSize),
            child: Scaffold(body: TranscriptionSplitter(viewModel: viewModel)),
          ),
        ),
      ),
    );
  }

  RecordingTranscription createTranscription(String label, String content) {
    final transcription = RecordingTranscription(label);
    transcription.content = content;
    return transcription;
  }

  group('Home page - Transcription splitter', () {
    testWidgets('splitscreen disabled only shows one list', (tester) async {
      await pumpSplitter(
        tester,
        splitScreen: false,
        surfaceSize: const Size(1200, 800),
        viewModel: HomeViewModel(),
      );

      expect(find.byType(TranscriptionsList), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().home__emptyFallback),
        findsOneWidget,
      );
      expect(find.byType(Row), findsNothing);
      expect(find.byType(Column), findsNothing);
      expect(find.byType(RotatedBox), findsNothing);
    });

    testWidgets('splitscreen landscape shows side-by-side lists', (
      tester,
    ) async {
      await pumpSplitter(
        tester,
        splitScreen: true,
        surfaceSize: const Size(1200, 800),
        viewModel: HomeViewModel(),
      );

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byType(TranscriptionsList), findsNWidgets(2));
      expect(find.byType(RotatedBox), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().home__emptyFallback),
        findsNWidgets(2),
      );
    });

    testWidgets('splitscreen portrait shows stacked lists', (tester) async {
      await pumpSplitter(
        tester,
        splitScreen: true,
        surfaceSize: const Size(500, 1200),
        viewModel: HomeViewModel(),
      );

      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(find.byType(TranscriptionsList), findsNWidgets(2));
      expect(find.byType(RotatedBox), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().home__emptyFallback),
        findsNWidgets(2),
      );
    });

    testWidgets('splitscreen transcripts shows on both lists', (tester) async {
      await pumpSplitter(
        tester,
        splitScreen: true,
        surfaceSize: const Size(500, 1200),
        viewModel: HomeViewModel(
          initialTranscriptions: [
            createTranscription('09:00', 'First'),
            createTranscription('09:01', 'Second'),
            createTranscription('09:02', 'Third'),
          ],
        ),
      );

      final firstFinder = find.text('First');
      expect(firstFinder, findsNWidgets(2));

      final secondFinder = find.text('Second');
      expect(secondFinder, findsNWidgets(2));

      final thirdFinder = find.text('Third');
      expect(thirdFinder, findsNWidgets(2));
    });
  });
}
