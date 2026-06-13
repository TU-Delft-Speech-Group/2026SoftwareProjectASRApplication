import 'dart:async';

import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<StreamingTranscriptionService>()])
import 'home_page_banners_test.mocks.dart';

class _FakeCoordinator implements RecordingCoordinator {
  final _ctrl = StreamController<RecordingEvent>.broadcast(sync: true);
  Object? startError;
  Object? stopError;

  @override
  Stream<RecordingEvent> get events => _ctrl.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {
    if (startError != null) throw startError!;
  }

  @override
  Future<String> stop() async {
    if (stopError != null) throw stopError!;
    return '';
  }

  @override
  void dispose() => _ctrl.close();

  void emit(RecordingEvent event) => _ctrl.add(event);
}

void main() {
  late MockAudioRecorder recorder;

  setUp(() {
    recorder = MockAudioRecorder();
    when(recorder.hasPermission()).thenAnswer((_) async => true);
    when(recorder.dispose()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, HomeViewModel viewModel) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(viewModel: viewModel),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HomePage - error banner', () {
    late _FakeCoordinator coordinator;
    late HomeViewModel viewModel;

    setUp(() {
      coordinator = _FakeCoordinator();
      viewModel = HomeViewModel(
        recorder: recorder,
        streamingService: MockStreamingTranscriptionService(),
        coordinator: coordinator,
      );
    });

    tearDown(() {
      viewModel.dispose();
      coordinator.dispose();
    });

    testWidgets('is absent before any failure', (tester) async {
      await pump(tester, viewModel);

      expect(
        find.text(AppLocalizationsEn().errors__transcribing),
        findsNothing,
      );
    });

    testWidgets('appears after RecordingFailed', (tester) async {
      await pump(tester, viewModel);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      coordinator.emit(RecordingFailed(StateError('encode failed')));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().errors__transcribing),
        findsOneWidget,
      );
    });

    testWidgets('disappears when a new recording starts', (tester) async {
      await pump(tester, viewModel);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      coordinator.emit(RecordingFailed(StateError('encode failed')));
      await tester.pumpAndSettle();

      expect(find.text(AppLocalizationsEn().errors__transcribing), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text(AppLocalizationsEn().errors__transcribing), findsNothing);
    });

    testWidgets('tapping the banner itself clears the error and starts recording', (tester) async {
      await pump(tester, viewModel);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      coordinator.emit(RecordingFailed(StateError('encode failed')));
      await tester.pumpAndSettle();

      expect(find.text(AppLocalizationsEn().errors__transcribing), findsOneWidget);

      await tester.tap(find.text(AppLocalizationsEn().errors__transcribing));
      await tester.pumpAndSettle();

      expect(find.text(AppLocalizationsEn().errors__transcribing), findsNothing);
      expect(viewModel.isTranscribing, isTrue);

      // clean up; stop the recording
      coordinator.emit(RecordingFailed(StateError('cleanup')));
      await tester.pumpAndSettle();
    });
  });

  group('HomePage : error banner on start failure', () {
    late _FakeCoordinator coordinator;
    late HomeViewModel viewModel;

    setUp(() {
      coordinator = _FakeCoordinator();
      coordinator.startError = StateError('microphone failed');
      viewModel = HomeViewModel(
        recorder: recorder,
        streamingService: MockStreamingTranscriptionService(),
        coordinator: coordinator,
      );
    });

    tearDown(() {
      viewModel.dispose();
      coordinator.dispose();
    });

    testWidgets('appears when coordinator.start() throws', (tester) async {
      await pump(tester, viewModel);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().errors__transcribing),
        findsOneWidget,
      );
    });
  });

  group('HomePage : error banner on stop failure', () {
    late _FakeCoordinator coordinator;
    late HomeViewModel viewModel;

    setUp(() async {
      coordinator = _FakeCoordinator();
      viewModel = HomeViewModel(
        recorder: recorder,
        streamingService: MockStreamingTranscriptionService(),
        coordinator: coordinator,
      );
    });

    tearDown(() {
      viewModel.dispose();
      coordinator.dispose();
    });

    testWidgets('appears when coordinator.stop() throws', (tester) async {
      await pump(tester, viewModel);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      coordinator.stopError = StateError('stop failed');

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().errors__transcribing),
        findsOneWidget,
      );
    });
  });

  group('HomePage - vocab fallback warning', () {
    testWidgets('is absent when a real streaming service is provided', (tester) async {
      final viewModel = HomeViewModel(
        recorder: recorder,
        streamingService: MockStreamingTranscriptionService(),
      );

      await pump(tester, viewModel);

      expect(
        find.text(AppLocalizationsEn().errors__vocabFallbackWarning),
        findsNothing,
      );

      viewModel.dispose();
    });

    testWidgets('is shown when no streaming service or text service is provided', (tester) async {
      final viewModel = HomeViewModel(recorder: recorder);

      await pump(tester, viewModel);

      expect(
        find.text(AppLocalizationsEn().errors__vocabFallbackWarning),
        findsOneWidget,
      );

      viewModel.dispose();
    });
  });
}
