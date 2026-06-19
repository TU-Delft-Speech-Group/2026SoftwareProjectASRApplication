import 'package:asr_application/services/audio/recorder_service.dart';
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
import 'home_page_menu_test.mocks.dart';

void main() {
  late MockAudioRecorder recorder;
  late MockRecorderService service;
  late HomeViewModel viewModel;

  setUp(() {
    recorder = MockAudioRecorder();
    service = MockRecorderService();
    when(recorder.hasPermission()).thenAnswer((_) async => true);
    when(service.start()).thenAnswer((_) async => {});
    viewModel = HomeViewModel(recorder: recorder, recorderService: service);
  });

  tearDown(() => viewModel.dispose());

  Future<void> loadScreen(WidgetTester tester) async {
    await testApp(tester, HomePage(viewModel: viewModel));
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
  });
}
