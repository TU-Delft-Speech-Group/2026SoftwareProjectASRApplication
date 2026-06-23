import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'dart:collection';

import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/ui/docs/widgets/docs_overview_page.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:asr_application/ui/home/widgets/recording_button.dart';
import 'package:asr_application/ui/settings/widgets/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

import '../../../testing/app.dart';
@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<RecorderService>()])
@GenerateNiceMocks([MockSpec<RecordingCoordinator>()])
@GenerateNiceMocks([MockSpec<ModelInstallController>()])
import 'home_page_menu_test.mocks.dart';

Future<void> navigateToInMenu(WidgetTester tester, IconData target) async {
  // Clicking on the settings item in the dropdown menu
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(target));
  await tester.pumpAndSettle();
}

void main() {
  late MockAudioRecorder recorder;
  late MockRecorderService service;
  late MockRecordingCoordinator mockRecordingCoordinator;
  late MockModelInstallController mockModelInstallController;
  late HomeViewModel viewModel;

  setUp(() {
    recorder = MockAudioRecorder();
    service = MockRecorderService();
    mockRecordingCoordinator = MockRecordingCoordinator();

    mockModelInstallController = MockModelInstallController();
    when(
      mockModelInstallController.getModelList(),
    ).thenAnswer((_) => ModelList(modelNames: UnmodifiableListView([])));

    when(recorder.hasPermission()).thenAnswer((_) async => true);
    when(service.start()).thenAnswer((_) async => {});
    viewModel = HomeViewModel(
      recorder: recorder,
      recorderService: service,
      coordinator: mockRecordingCoordinator,
    );
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
    group('settings', () {
      testWidgets('navigate to setting through dropdown menu', (tester) async {
        // Loading the home widget
        await loadScreen(tester);

        await navigateToInMenu(tester, Icons.settings);

        // Check if the settings page is shown
        expect(find.byType(SettingsPage), findsOneWidget);
      });

      testWidgets('transcription should stop when navigating to settings', (
        tester,
      ) async {
        await loadScreen(tester);

        //start transcription
        await tester.tap(find.byType(RecordingButton));
        await tester.pumpAndSettle();
        verifyNever(mockRecordingCoordinator.stop());

        await navigateToInMenu(tester, Icons.settings);

        verify(mockRecordingCoordinator.stop()).called(1);
      });

      testWidgets(
        'user should be notified of transcription stopping when navigating to settings',
        (tester) async {
          await loadScreen(tester);

          //start transcription
          await tester.tap(find.byType(RecordingButton));
          await tester.pumpAndSettle();

          await navigateToInMenu(tester, Icons.settings);

          expect(
            find.text(AppLocalizationsEn().event_stoppedRecording),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'user should not be notified of transcription stopping if not started',
        (tester) async {
          await loadScreen(tester);

          await navigateToInMenu(tester, Icons.settings);

          expect(
            find.text(AppLocalizationsEn().event_stoppedRecording),
            findsNothing,
          );
        },
      );
    });

    group('docs', () {
      testWidgets('navigate to docs through menu', (tester) async {
        // Loading the home widget
        await loadScreen(tester);

        // Clicking on the manuals item in the dropdown menu
        await navigateToInMenu(tester, Icons.menu_book);

        // Check if the settings page is shown
        expect(find.byType(DocsOverviewPage), findsOneWidget);
      });

      testWidgets('transcription should stop when navigating to docs', (
        tester,
      ) async {
        await loadScreen(tester);

        //start transcription
        await tester.tap(find.byType(RecordingButton));
        await tester.pumpAndSettle();
        verifyNever(mockRecordingCoordinator.stop());

        await navigateToInMenu(tester, Icons.menu_book);

        verify(mockRecordingCoordinator.stop()).called(1);
      });

      testWidgets(
        'user should be notified of transcription stopping when navigating t odocs',
        (tester) async {
          await loadScreen(tester);

          //start transcription
          await tester.tap(find.byType(RecordingButton));
          await tester.pumpAndSettle();

          await navigateToInMenu(tester, Icons.menu_book);

          expect(
            find.text(AppLocalizationsEn().event_stoppedRecording),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'user should not be notified of transcription stopping if not started',
        (tester) async {
          await loadScreen(tester);

          await navigateToInMenu(tester, Icons.menu_book);

          expect(
            find.text(AppLocalizationsEn().event_stoppedRecording),
            findsNothing,
          );
        },
      );
    });
  });
}
