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
    super.hasActiveModel,
  })  : _isTranscribing = isTranscribing,
        _hasRecordingPermissions = hasRecordingPermissions,
        _hasActiveModelOverride = hasActiveModel;

  bool _isTranscribing;
  final bool? _hasRecordingPermissions;
  final bool _hasActiveModelOverride;

  @override
  bool get isTranscribing => _isTranscribing;

  @override
  bool? get hasRecordingPermissions => _hasRecordingPermissions;

  @override
  bool get hasActiveModel => _hasActiveModelOverride;

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

    testWidgets('Without an active model, prompts to add one', (tester) async {
      final viewModel = FakeHomeViewModel(
        isTranscribing: false,
        hasRecordingPermissions: true,
        hasActiveModel: false,
      );

      await generateWidget(tester, viewModel: viewModel);

      expect(
        find.text(AppLocalizationsEn().home__noModelSelected),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('No-model message takes precedence over no-permission', (
      tester,
    ) async {
      final viewModel = FakeHomeViewModel(
        isTranscribing: false,
        hasRecordingPermissions: false,
        hasActiveModel: false,
      );

      await generateWidget(tester, viewModel: viewModel);

      expect(
        find.text(AppLocalizationsEn().home__noModelSelected),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().home__recordingPermission),
        findsNothing,
      );
    });
  });
}
