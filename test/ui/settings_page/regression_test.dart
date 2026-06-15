import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/main.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/services/pipeline/asr_runtime_controller.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/settings_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';
import 'package:snaptest/snaptest.dart';

import '../../../testing/fakes/services/pipeline/fake_asr_runtime.dart';
@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<ModelInstallController>()])
import 'regression_test.mocks.dart';

void main() {
  late AsrRuntimeController asrController;
  late AsrRuntime fakeRuntime;
  late HomeViewModel homeViewModel;
  late MockAudioRecorder mockRecorder;
  late ModelInstallController modelController;
  late SettingsRepository settingsRepository;

  setUp(() async {
    fakeRuntime = FakeAsrRuntime();
    asrController = AsrRuntimeController(loadRuntime: (_) async => fakeRuntime);
    await asrController.loadModel('model-with-metadata');

    mockRecorder = MockAudioRecorder();
    when(mockRecorder.hasPermission()).thenAnswer((_) async => true);

    settingsRepository = SettingsRepository(
      save: (String k, String v) async => Mock(),
      preferences: {},
    );

    homeViewModel = HomeViewModel(recorder: mockRecorder);
    modelController = MockModelInstallController();
  });

  tearDown(() {
    homeViewModel.dispose();
  });

  Future<void> loadScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MainApp(
        asrController: asrController,
        homeViewModel: homeViewModel,
        installController: modelController,
        settingsRepository: settingsRepository,
      ),
    );
    await tester.tap(find.byType(SettingsButton));
    await tester.pumpAndSettle();
  }

  snapTest('Settings page - initial', (tester) async {
    await loadScreen(tester);

    await tester.tap(find.text(AppLocalizationsEn().settings__fontSizeMedium));

    await snap(name: 'settings_initial', matchToGolden: true);
  });

  snapTest('Settings page - larger text', (tester) async {
    await loadScreen(tester);

    await tester.tap(find.text(AppLocalizationsEn().settings__fontSizeLarge));

    await snap(name: 'settings_larger', matchToGolden: true);
  });

  snapTest('Settings page - XL text', (tester) async {
    await loadScreen(tester);

    await tester.tap(find.text(AppLocalizationsEn().settings__fontSizeXl));

    await snap(name: 'settings_xl', matchToGolden: true);
  });
}
