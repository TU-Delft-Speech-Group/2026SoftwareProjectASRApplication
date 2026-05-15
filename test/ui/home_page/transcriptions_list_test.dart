import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/transcriptions_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> generateWidget(
    WidgetTester tester, {
    required HomeViewModel viewModel,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TranscriptionsList(viewModel: viewModel)),
      ),
    );
  }

  RecordingTranscription createTranscription(String label, String content) {
    final transcription = RecordingTranscription(label);
    transcription.content = content;
    return transcription;
  }

  group('Home page - Transcriptions list', () {
    testWidgets('No transcriptions, shows fallback text', (tester) async {
      final viewModel = HomeViewModel();

      await generateWidget(tester, viewModel: viewModel);

      expect(
        find.text(AppLocalizationsEn().home__emptyFallback),
        findsOneWidget,
      );
    });

    testWidgets('Transcription shows label first, than content', (
      tester,
    ) async {
      final viewModel = HomeViewModel();
      viewModel.recentTranscriptions.add(
        createTranscription('09:30', 'First transcription'),
      );

      await generateWidget(tester, viewModel: viewModel);

      final labelFinder = find.text('09:30');
      final contentFinder = find.text('First transcription');

      expect(labelFinder, findsOneWidget);
      expect(contentFinder, findsOneWidget);
      expect(
        tester.getTopLeft(labelFinder).dy,
        lessThan(tester.getTopLeft(contentFinder).dy),
      );
    });

    testWidgets('3 transcriptions shows latest at the bottom', (tester) async {
      final viewModel = HomeViewModel();
      viewModel.recentTranscriptions.addAll([
        createTranscription('09:00', 'First'),
        createTranscription('09:01', 'Second'),
        createTranscription('09:02', 'Third'),
      ]);

      await generateWidget(tester, viewModel: viewModel);

      final firstFinder = find.text('First');
      final secondFinder = find.text('Second');
      final thirdFinder = find.text('Third');

      expect(firstFinder, findsOneWidget);
      expect(secondFinder, findsOneWidget);
      expect(thirdFinder, findsOneWidget);
      expect(
        tester.getTopLeft(firstFinder).dy,
        lessThan(tester.getTopLeft(secondFinder).dy),
      );
      expect(
        tester.getTopLeft(secondFinder).dy,
        lessThan(tester.getTopLeft(thirdFinder).dy),
      );
    });

    testWidgets('15 transcriptions shows only the last 10', (tester) async {
      final viewModel = HomeViewModel();
      for (int i = 0; i < 15; i++) {
        viewModel.recentTranscriptions.add(
          createTranscription(i.toString(), 'Entry $i'),
        );
      }

      await generateWidget(tester, viewModel: viewModel);

      expect(find.text('Entry 0'), findsNothing);
      expect(find.text('Entry 4'), findsNothing);
      expect(find.text('Entry 14'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Entry 5'),
        10,
        scrollable: find.byType(Scrollable),
      );

      expect(find.text('Entry 5'), findsOneWidget);
    });
  });
}
