import 'dart:async';

import 'package:asr_application/main.dart';
import 'package:asr_application/services/pipeline/asr_runtime_controller.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';
import 'package:snaptest/snaptest.dart';
import '../../../testing/fakes/services/pipeline/fake_asr_runtime.dart';

@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<RecordingCoordinator>()])
import 'regression_test.mocks.dart';

class _FakeCoordinator implements RecordingCoordinator {
  final _ctrl = StreamController<RecordingEvent>.broadcast(sync: true);
  String stopFallback = '';

  @override
  Stream<RecordingEvent> get events => _ctrl.stream;

  @override
  Future<void> tick() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<String> stop() async => stopFallback;

  @override
  void dispose() => _ctrl.close();

  void emit(RecordingEvent event) => _ctrl.add(event);
}

void main() {
  late AsrRuntimeController asrController;
  late AsrRuntime fakeRuntime;
  late HomeViewModel homeViewModel;
  late MockAudioRecorder mockRecorder;
  late MockRecordingCoordinator mockCoordinator;

  const transcriptionFallback =
      'Et eiusmod laboris occaecat consequat quis eiusmod in Lorem elit velit irure ea reprehenderit consectetur.';

  setUp(() async {
    fakeRuntime = FakeAsrRuntime();
    asrController = AsrRuntimeController(loadRuntime: (_) async => fakeRuntime);
    await asrController.loadModel('EnglishGigaspeechConformerFBank_M01');

    mockRecorder = MockAudioRecorder();
    when(mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(mockRecorder.stop()).thenAnswer((_) async => null);
    when(mockRecorder.dispose()).thenAnswer((_) async {});

    mockCoordinator = MockRecordingCoordinator();
    when(mockCoordinator.start()).thenAnswer((_) async => {});
    when(mockCoordinator.stop()).thenAnswer((_) async => transcriptionFallback);

    homeViewModel = HomeViewModel(
      recorder: mockRecorder,
      streamingService: fakeRuntime.transcriptionService,
      coordinator: mockCoordinator,
    );
  });

  tearDown(() {
    homeViewModel.dispose();
  });

  Future<void> loadScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MainApp(asrController: asrController, homeViewModel: homeViewModel),
    );
    await tester.pumpAndSettle();
  }

  snapTest('Homepage - initial', (tester) async {
    await withClock(Clock(() => DateTime(1976)), () async {
      await loadScreen(tester);
    });

    await snap(name: 'homepage_initial', matchToGolden: true);
  });

  snapTest('Homepage - transcribing', (tester) async {
    await withClock(Clock(() => DateTime(1976)), () async {
      await loadScreen(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    });

    await snap(name: 'homepage_transcribing', matchToGolden: true);

    // Stop recording after the snapshot so the periodic chunk timer is cancelled
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  });

  snapTest('Homepage - finished', (tester) async {
    await withClock(Clock(() => DateTime(1976)), () async {
      await loadScreen(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    });

    await snap(name: 'homepage_finished', matchToGolden: true);
  });

  snapTest('Homepage - error', (tester) async {
    final fakeCoordinator = _FakeCoordinator();
    final errorViewModel = HomeViewModel(
      recorder: mockRecorder,
      streamingService: fakeRuntime.transcriptionService,
      coordinator: fakeCoordinator,
    );

    await withClock(Clock(() => DateTime(1976)), () async {
      await tester.pumpWidget(
        MainApp(asrController: asrController, homeViewModel: errorViewModel),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      fakeCoordinator.emit(RecordingFailed(StateError('encode failed')));
      await tester.pumpAndSettle();
    });

    await snap(name: 'homepage_error', matchToGolden: false);

    errorViewModel.dispose();
    fakeCoordinator.dispose();
  });

  snapTest('Homepage - vocab fallback warning', (tester) async {
    final fallbackViewModel = HomeViewModel(
      recorder: mockRecorder,
      coordinator: mockCoordinator,
    );

    await withClock(Clock(() => DateTime(1976)), () async {
      await tester.pumpWidget(
        MainApp(asrController: asrController, homeViewModel: fallbackViewModel),
      );
      await tester.pumpAndSettle();
    });

    await snap(name: 'homepage_vocab_fallback', matchToGolden: false);

    fallbackViewModel.dispose();
  });
}
