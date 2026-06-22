import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/ui/docs/widgets/docs_overview_page.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:asr_application/ui/settings/widgets/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

import '../../../testing/app.dart';
@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<RecorderService>()])
@GenerateNiceMocks([MockSpec<ModelInstallController>()])
import 'home_page_menu_test.mocks.dart';

/// View model whose transcribing state can be set directly, so menu tests can
/// exercise the "recording" path without spinning up the real audio pipeline
/// (which leaves timers pending after the test).
class _FakeRecordingViewModel extends HomeViewModel {
  _FakeRecordingViewModel({
    required super.recorder,
    required super.recorderService,
    required bool isTranscribing,
  }) : _isTranscribing = isTranscribing;

  bool _isTranscribing;

  @override
  bool get isTranscribing => _isTranscribing;

  @override
  Future<void> toggleTranscribing() async {
    _isTranscribing = !_isTranscribing;
    notifyListeners();
  }
}

void main() {
  late MockAudioRecorder recorder;
  late MockRecorderService service;
  late MockModelInstallController mockModelInstallController;
  late HomeViewModel viewModel;

  setUp(() {
    recorder = MockAudioRecorder();
    service = MockRecorderService();
    mockModelInstallController = MockModelInstallController();
    when(recorder.hasPermission()).thenAnswer((_) async => true);
    when(service.start()).thenAnswer((_) async => {});
    viewModel = HomeViewModel(recorder: recorder, recorderService: service);
  });

  tearDown(() => viewModel.dispose());

  Future<void> loadScreen(WidgetTester tester) async {
    await testApp(
      tester,
      HomePage(
        viewModel: viewModel,
        modelController: mockModelInstallController,
      ),
    );
  }

  group('Home page - Menu', () {
    testWidgets('navigate to setting through dropdown menu', (tester) async {
      // Loading the home widget
      await loadScreen(tester);

      // Clicking on the settings item in the dropdown menu
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Check if the settings page is shown
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('navigate to docs through menu', (tester) async {
      // Loading the home widget
      await loadScreen(tester);

      // Clicking on the manuals item in the dropdown menu
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu_book));
      await tester.pumpAndSettle();

      // Check if the settings page is shown
      expect(find.byType(DocsOverviewPage), findsOneWidget);
    });

    testWidgets('menu does not open while recording', (tester) async {
      viewModel = _FakeRecordingViewModel(
        recorder: recorder,
        recorderService: service,
        isTranscribing: true,
      );
      await loadScreen(tester);

      // Tapping the menu should not open the dropdown...
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // ...so the settings item never appears, and a message is shown instead.
      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().home__stopRecordingToNavigate),
        findsOneWidget,
      );

      // Drain the snackbar's auto-dismiss timer so the test ends cleanly.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('menu works again after recording stops', (tester) async {
      final fakeViewModel = _FakeRecordingViewModel(
        recorder: recorder,
        recorderService: service,
        isTranscribing: true,
      );
      viewModel = fakeViewModel;
      await loadScreen(tester);

      // Stop recording, which re-enables the menu.
      await fakeViewModel.toggleTranscribing();
      await tester.pumpAndSettle();

      // The menu should navigate to settings as usual.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });
}
