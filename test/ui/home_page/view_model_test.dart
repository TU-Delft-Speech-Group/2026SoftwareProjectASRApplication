import 'dart:async';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<RecorderService>()])
@GenerateNiceMocks([MockSpec<StreamingTranscriptionService>()])
import 'view_model_test.mocks.dart';

class _FakeCoordinator implements RecordingCoordinator {
  final _ctrl = StreamController<RecordingEvent>.broadcast(sync: true);
  String stopFallback = '';

  @override
  Stream<RecordingEvent> get events => _ctrl.stream;

  @override
  Future<void> start() async {}

  @override
  Future<String> stop() async => stopFallback;

  @override
  void dispose() => _ctrl.close();

  void emit(RecordingEvent event) => _ctrl.add(event);
}

void main() {
  group('Home page - View Model', () {
    late MockAudioRecorder recorder;
    late MockRecorderService service;
    late HomeViewModel viewModel;

    setUp(() async {
      recorder = MockAudioRecorder();
      service = MockRecorderService();
      when(recorder.hasPermission()).thenAnswer((_) async => true);
      when(service.start()).thenAnswer((_) async => {});
      viewModel = HomeViewModel(recorder: recorder, recorderService: service);
    });

    test('first toggle enables transcribing', () async {
      await withClock(Clock(() => DateTime(2026, 5, 15, 12, 00, 00)), () async {
        await viewModel.toggleTranscribing();
      });
      expect(viewModel.isTranscribing, isTrue);
      expect(viewModel.recentTranscriptions, hasLength(1));
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions.first.content, '...');
    });

    test('second toggle disables transcribing', () async {
      for (int i = 0; i < 2; i++) {
        await withClock(
          Clock(() => DateTime(2026, 5, 15, 12, 10 * i, 00)),
          () async {
            await viewModel.toggleTranscribing();
          },
        );
      }
      expect(viewModel.isTranscribing, isFalse);
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions, hasLength(1));
      expect(viewModel.recentTranscriptions.first.content, isNot('...'));
    });

    test('third toggle enables new transcribing', () async {
      for (int i = 0; i < 3; i++) {
        await withClock(
          Clock(() => DateTime(2026, 5, 15, 12, 10 * i, 00)),
          () async {
            await viewModel.toggleTranscribing();
          },
        );
      }
      expect(viewModel.isTranscribing, isTrue);
      expect(viewModel.recentTranscriptions, hasLength(2));
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions.last.label, matches('12:20'));
      expect(viewModel.recentTranscriptions.last.content, '...');
    });

    test('fourth toggle disables transcribing', () async {
      for (int i = 0; i < 4; i++) {
        await withClock(
          Clock(() => DateTime(2026, 5, 15, 12, 10 * i, 00)),
          () async {
            await viewModel.toggleTranscribing();
          },
        );
      }
      expect(viewModel.isTranscribing, isFalse);
      expect(viewModel.recentTranscriptions, hasLength(2));
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions.last.label, matches('12:20'));
      expect(viewModel.recentTranscriptions.last.content, isNot('...'));
    });

    group('event-driven state transitions', () {
      late MockAudioRecorder eventRecorder;
      late _FakeCoordinator coordinator;
      late HomeViewModel eventViewModel;

      setUp(() async {
        eventRecorder = MockAudioRecorder();
        coordinator = _FakeCoordinator();
        when(eventRecorder.hasPermission()).thenAnswer((_) async => true);
        eventViewModel = HomeViewModel(
          recorder: eventRecorder,
          coordinator: coordinator,
        );
        await withClock(
          Clock(() => DateTime(2026, 5, 15, 12, 0, 0)),
          () => eventViewModel.toggleTranscribing(),
        );
      });

      test('DecodingStarted sets isDecoding on the active entry', () {
        coordinator.emit(const DecodingStarted());
        expect(eventViewModel.recentTranscriptions.last.isDecoding, isTrue);
      });

      test('DecodingFinished clears isDecoding', () {
        coordinator.emit(const DecodingStarted());
        coordinator.emit(const DecodingFinished());
        expect(eventViewModel.recentTranscriptions.last.isDecoding, isFalse);
      });

      test('HypothesisUpdated updates content', () {
        coordinator.emit(const HypothesisUpdated('hello world'));
        expect(
          eventViewModel.recentTranscriptions.last.content,
          equals('hello world'),
        );
      });

      test(
        'SegmentCommitted finalizes entry content and opens a new pending entry',
        () {
          coordinator.emit(const SegmentCommitted('Hello.'));
          expect(eventViewModel.recentTranscriptions, hasLength(2));
          expect(
            eventViewModel.recentTranscriptions.first.content,
            equals('Hello.'),
          );
          expect(
            eventViewModel.recentTranscriptions.last.content,
            equals('...'),
          );
        },
      );

      test('notifyListeners is called for each event', () {
        var count = 0;
        eventViewModel.addListener(() => count++);
        coordinator.emit(const DecodingStarted());
        coordinator.emit(const DecodingFinished());
        coordinator.emit(const HypothesisUpdated('hi'));
        coordinator.emit(const SegmentCommitted('Hi.'));
        expect(count, equals(4));
      });

      test(
        'stop with pending entry applies coordinator fallback text',
        () async {
          coordinator.stopFallback = 'partial transcript';
          await eventViewModel.toggleTranscribing();
          expect(
            eventViewModel.recentTranscriptions.last.content,
            equals('partial transcript'),
          );
        },
      );

      test(
        'stop with non-pending entry does not overwrite existing content',
        () async {
          coordinator.emit(const HypothesisUpdated('already set'));
          coordinator.stopFallback = 'should not overwrite';
          await eventViewModel.toggleTranscribing();
          expect(
            eventViewModel.recentTranscriptions.last.content,
            equals('already set'),
          );
        },
      );
    });

    group('sentence-confirmed scroll', () {
      late MockStreamingTranscriptionService streamingService;
      setUp(() {
        streamingService = MockStreamingTranscriptionService();
        when(service.frames).thenReturn([
          SampleWindow([0.0], [0.0]),
        ]);
        when(service.silenceDurationMs).thenReturn(0);
        when(streamingService.process(any)).thenAnswer(
          (_) async => const SegmentResult(
            confirmedText: 'Hello.',
            hypothesis: 'Hello.',
          ),
        );
        viewModel = HomeViewModel(
          recorder: recorder,
          recorderService: service,
          streamingService: streamingService,
        );
      });

      test('appends a new RecordingTranscription entry', () async {
        await withClock(Clock(() => DateTime(2026, 5, 15, 12, 0, 0)), () async {
          await viewModel.toggleTranscribing();
          await viewModel.toggleTranscribing();
        });

        expect(viewModel.recentTranscriptions, hasLength(2));
        expect(viewModel.recentTranscriptions.first.content, equals('Hello.'));
      });
    });
  });

  group('Home page - View Model error handling', () {
    late MockAudioRecorder errorRecorder;
    late _FakeCoordinator coordinator;
    late HomeViewModel viewModel;

    setUp(() async {
      errorRecorder = MockAudioRecorder();
      coordinator = _FakeCoordinator();
      when(errorRecorder.hasPermission()).thenAnswer((_) async => true);
      viewModel = HomeViewModel(
        recorder: errorRecorder,
        coordinator: coordinator,
      );
      await withClock(
        Clock(() => DateTime(2026, 5, 15, 12, 0, 0)),
        () => viewModel.toggleTranscribing(),
      );
    });

    test('recordingError is null before any failure', () {
      expect(viewModel.recordingError, isNull);
    });

    test('RecordingFailed does not add a new transcription entry', () {
      final countBefore = viewModel.recentTranscriptions.length;
      coordinator.emit(RecordingFailed(StateError('forced failure')));
      expect(viewModel.recentTranscriptions.length, equals(countBefore));
    });

    test('RecordingFailed does not clear content that was already set', () {
      coordinator.emit(const HypothesisUpdated('partial text'));
      coordinator.emit(RecordingFailed(StateError('forced failure')));
      expect(viewModel.recentTranscriptions.last.content, equals('partial text'));
    });

    test('RecordingFailed sets recordingError', () {
      final error = StateError('encoder failed');
      coordinator.emit(RecordingFailed(error));
      expect(viewModel.recordingError, same(error));
    });

    test('RecordingFailed clears isTranscribing', () {
      coordinator.emit(RecordingFailed(StateError('forced failure')));
      expect(viewModel.isTranscribing, isFalse);
    });

    test('RecordingFailed clears isDecoding on the active entry', () {
      coordinator.emit(const DecodingStarted());
      coordinator.emit(RecordingFailed(StateError('forced failure')));
      expect(viewModel.recentTranscriptions.last.isDecoding, isFalse);
    });

    test('RecordingFailed clears pending content to empty string', () {
      expect(viewModel.recentTranscriptions.last.isPending, isTrue);
      coordinator.emit(RecordingFailed(StateError('forced failure')));
      expect(viewModel.recentTranscriptions.last.content, equals(''));
    });

    test('recordingError resets to null when a new recording starts', () async {
      coordinator.emit(RecordingFailed(StateError('forced failure')));
      expect(viewModel.recordingError, isNotNull);

      await withClock(
        Clock(() => DateTime(2026, 5, 15, 12, 1, 0)),
        () => viewModel.toggleTranscribing(),
      );
      expect(viewModel.recordingError, isNull);
    });

    test('notifyListeners is called on RecordingFailed', () {
      var count = 0;
      viewModel.addListener(() => count++);
      coordinator.emit(RecordingFailed(StateError('forced failure')));
      expect(count, equals(1));
    });
  });
}
