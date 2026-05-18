import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/recording_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHomeViewModel extends HomeViewModel {
  FakeHomeViewModel({
    required bool isTranscribing,
    required bool? hasRecordingPermissions,
  }) : _isTranscribing = isTranscribing,
       _hasRecordingPermissions = hasRecordingPermissions;

  bool _isTranscribing;
  final bool? _hasRecordingPermissions;

  @override
  bool get isTranscribing => _isTranscribing;

  @override
  bool? get hasRecordingPermissions => _hasRecordingPermissions;

  @override
  Future<void> toggleTranscribing() async {
    _isTranscribing = !_isTranscribing;
    notifyListeners();
  }
}

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
      final viewModel = FakeHomeViewModel(
        isTranscribing: false,
        hasRecordingPermissions: true,
      );

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
      final viewModel = FakeHomeViewModel(
        isTranscribing: false,
        hasRecordingPermissions: true,
      );

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

    testWidgets('Without microphone permission, the button is not shown', (
      tester,
    ) async {
      final viewModel = FakeHomeViewModel(
        isTranscribing: false,
        hasRecordingPermissions: false,
      );

      await generateWidget(tester, viewModel: viewModel);

      expect(
        find.text(AppLocalizationsEn().home__recordingPermission),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(viewModel.isTranscribing, isFalse);
    });
  });
}
