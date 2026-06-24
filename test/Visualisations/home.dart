import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';
import 'package:snaptest/snaptest.dart';

import '../../testing/fakes/services/pipeline/fake_asr_runtime.dart';
@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<RecordingCoordinator>()])
@GenerateNiceMocks([MockSpec<ModelInstallController>()])
import 'home.mocks.dart';
import 'pump.dart';

void main() {
  late AsrRuntime fakeRuntime;
  late HomeViewModel homeViewModel;
  late MockAudioRecorder mockRecorder;
  late MockRecordingCoordinator mockCoordinator;

  setUp(() async {
    fakeRuntime = FakeAsrRuntime();

    mockRecorder = MockAudioRecorder();
    when(mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(mockRecorder.stop()).thenAnswer((_) async => null);
    when(mockRecorder.dispose()).thenAnswer((_) async {});

    mockCoordinator = MockRecordingCoordinator();

    homeViewModel = HomeViewModel(
      recorder: mockRecorder,
      streamingService: fakeRuntime.transcriptionService,
      coordinator: mockCoordinator,
    );
  });

  tearDown(() {
    homeViewModel.dispose();
  });

  snapTest('Homepage - blank', (tester) async {
    await withClock(Clock(() => DateTime(1976)), () async {
      await pump(
        tester,
        HomePage(
          viewModel: homeViewModel,
          modelController: MockModelInstallController(),
        ),
      );
    });

    await snap();
  });

  snapTest('Homepage - start', (tester) async {
    await withClock(Clock(() => DateTime(1976)), () async {
      homeViewModel.recentTranscriptions.add(
        transcript('12:55', "This presentation will begin shortly."),
      );
      await pump(
        tester,
        HomePage(
          viewModel: homeViewModel,
          modelController: MockModelInstallController(),
        ),
      );
    });

    await snap();
  });

  snapTest('Homepage - intro', (tester) async {
    await withClock(Clock(() => DateTime(2026, 06, 25, 13, 3)), () async {
      homeViewModel.recentTranscriptions.add(
        transcript('13.02', "Welcome to the endterm presentation."),
      );
      await pump(
        tester,
        HomePage(
          viewModel: homeViewModel,
          modelController: MockModelInstallController(),
        ),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    });

    await snap();
  });

  snapTest('Homepage - splitscreen', (tester) async {
    await withClock(Clock(() => DateTime(2026, 06, 25, 13, 10)), () async {
      homeViewModel.recentTranscriptions.add(
        transcript('13.08', "Live splitscreen transcription"),
      );
      final settings = await pump(
        tester,
        HomePage(
          viewModel: homeViewModel,
          modelController: MockModelInstallController(),
        ),
      );
      settings.setSplitscreen(true);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    });

    await snap();
  });
}

RecordingTranscription transcript(String label, String content) {
  final trans = RecordingTranscription(label);
  trans.content = content;
  return trans;
}
