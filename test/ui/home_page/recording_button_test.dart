import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/recording_button.dart';
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
        home: Scaffold(body: RecordingButton(viewModel: viewModel)),
      ),
    );
  }

  group('Home page - Recording button', () {
    testWidgets('Clicking the button enables transcribing', (tester) async {
      final viewModel = HomeViewModel();

      await generateWidget(tester, viewModel: viewModel);

      expect(
        find.text(AppLocalizationsEn().home__startRecording),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(viewModel.isTranscribing, isFalse);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(viewModel.isTranscribing, isTrue);
      expect(
        find.text(AppLocalizationsEn().home__stopRecording),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    });

    testWidgets('Clicking the button again disables transcribing', (
      tester,
    ) async {
      final viewModel = HomeViewModel();

      await generateWidget(tester, viewModel: viewModel);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(
        find.text(AppLocalizationsEn().home__stopRecording),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(viewModel.isTranscribing, isTrue);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(
        find.text(AppLocalizationsEn().home__startRecording),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(viewModel.isTranscribing, isFalse);
    });
  });
}
