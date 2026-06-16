import 'dart:async';
import 'dart:typed_data';

import 'package:asr_application/exceptions/pipeline/pipeline_stage_exception.dart';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'package:asr_application/ui/home/view_models/recording_coordinator.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRecorder implements RecorderService {
  @override
  var frames = <SampleWindow>[];
  @override
  var silenceDurationMs = 0;
  var initializeCalls = 0;
  var startCalls = 0;
  var stopCalls = 0;

  // When null, mirrors the simple case where the last chunk decides
  // (silenceDurationMs == 0 means speech). Set explicitly to model speech
  // that occurred mid-window while the last chunk was silent.
  bool? speechSinceLastCheck;

  @override
  bool takeSpeechSinceLastCheck() {
    final hadSpeech = speechSinceLastCheck ?? silenceDurationMs == 0;
    speechSinceLastCheck = null;
    return hadSpeech;
  }

  @override
  bool get isRecording => startCalls > stopCalls;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async {}
}

class _FakeStreaming implements StreamingTranscriptionService {
  @override
  String confirmedText = '';
  final _results = <StreamResult?>[];
  final _errors = <Object>[];
  var resetCalls = 0;
  var commitCalls = 0;
  int? lastSkipTo;

  void queueResult(StreamResult? result) => _results.add(result);
  void queueError(Object error) => _errors.add(error);

  @override
  int get maxBufferFrames => 1500;

  @override
  int get bufferLength => 0;

  @override
  Future<StreamResult?> process(List<Float32List> allFrames) async {
    if (_errors.isNotEmpty) throw _errors.removeAt(0);
    return _results.isNotEmpty ? _results.removeAt(0) : null;
  }

  @override
  void reset() => resetCalls++;

  @override
  void commit() => commitCalls++;

  @override
  void skipTo(int frameCount) => lastSkipTo = frameCount;
}

// one speech frame (content ignored by fakes, but must be non-empty for _collectFrames)
final _oneFrame = SampleWindow([0.0], [0.0]);

void main() {
  group('RecordingCoordinator', () {
    late _FakeRecorder recorder;
    late _FakeStreaming streaming;
    late RecordingCoordinator coordinator;

    setUp(() {
      recorder = _FakeRecorder();
      streaming = _FakeStreaming();
      coordinator = RecordingCoordinator(
        recorder: recorder,
        streaming: streaming,
      );
    });

    tearDown(() => coordinator.dispose());

    group('initialize', () {
      test('delegates to recorder', () async {
        await coordinator.initialize();
        expect(recorder.initializeCalls, equals(1));
      });
    });

    group('start', () {
      test('resets the streaming service', () async {
        await coordinator.start();
        expect(streaming.resetCalls, equals(1));
      });

      test('starts the recorder', () async {
        await coordinator.start();
        expect(recorder.startCalls, equals(1));
      });
    });

    group('manual ticks (chunkInterval: null)', () {
      test('tick processes frames and emits events without the timer',
          () async {
        final manual = RecordingCoordinator(
          recorder: recorder,
          streaming: streaming,
          chunkInterval: null,
        );
        final events = <RecordingEvent>[];
        manual.events.listen(events.add);
        recorder.frames = [_oneFrame];

        await manual.start();
        await manual.tick();

        expect(events.whereType<DecodingStarted>(), isNotEmpty);
        manual.dispose();
      });

      test('no processing happens without an explicit tick', () async {
        final manual = RecordingCoordinator(
          recorder: recorder,
          streaming: streaming,
          chunkInterval: null,
        );
        final events = <RecordingEvent>[];
        manual.events.listen(events.add);
        recorder.frames = [_oneFrame];

        await manual.start();
        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(events, isEmpty);
        manual.dispose();
      });
    });

    group('stop', () {
      test('stops the recorder', () async {
        await coordinator.start();
        await coordinator.stop();
        expect(recorder.stopCalls, equals(1));
      });

      test('returns confirmedText as fallback when no frames were processed',
          () async {
        streaming.confirmedText = 'partial result';
        recorder.frames = [];
        await coordinator.start();
        final result = await coordinator.stop();
        expect(result, equals('partial result'));
      });

      test('returns empty string when nothing was confirmed and no frames',
          () async {
        recorder.frames = [];
        await coordinator.start();
        final result = await coordinator.stop();
        expect(result, isEmpty);
      });
    });

    group('event emission', () {
      test('emits no events when recorder has no frames', () async {
        final events = <RecordingEvent>[];
        coordinator.events.listen(events.add);
        recorder.frames = [];

        await coordinator.start();
        await coordinator.stop();

        expect(events, isEmpty);
      });

      test(
          'skips processing and advances watermark in waiting-for-speech with silence',
          () async {
        final events = <RecordingEvent>[];
        coordinator.events.listen(events.add);
        recorder.frames = [_oneFrame];
        recorder.silenceDurationMs = 300;

        await coordinator.start();
        await coordinator.stop();

        expect(events, isEmpty);
        expect(streaming.lastSkipTo, equals(1));
      });

      test(
          'does not skip when speech occurred mid-window even if the last '
          'chunk was silent', () async {
        final events = <RecordingEvent>[];
        coordinator.events.listen(events.add);
        recorder.frames = [_oneFrame];
        recorder.silenceDurationMs = 300; // last chunk silent
        recorder.speechSinceLastCheck = true; // speech earlier in the window

        await coordinator.start();
        await coordinator.tick();

        expect(events, contains(isA<DecodingStarted>()));
        expect(streaming.lastSkipTo, isNull);
      });

      test('emits DecodingStarted when speech is detected', () async {
        final events = <RecordingEvent>[];
        coordinator.events.listen(events.add);
        recorder.frames = [_oneFrame];
        recorder.silenceDurationMs = 0;

        await coordinator.start();
        await coordinator.stop();

        expect(events, contains(isA<DecodingStarted>()));
      });

      test('emits HypothesisUpdated with hypothesis text on OngoingResult',
          () async {
        final events = <RecordingEvent>[];
        coordinator.events.listen(events.add);
        recorder.frames = [_oneFrame];
        recorder.silenceDurationMs = 0;
        streaming.queueResult(
          const OngoingResult(confirmedText: '', hypothesis: 'hello world'),
        );

        await coordinator.start();
        await coordinator.stop();

        final updates = events.whereType<HypothesisUpdated>();
        expect(updates, isNotEmpty);
        expect(updates.first.displayText, equals('hello world'));
      });

      test('emits SegmentCommitted with confirmed text on SegmentResult',
          () async {
        final events = <RecordingEvent>[];
        coordinator.events.listen(events.add);
        recorder.frames = [_oneFrame];
        recorder.silenceDurationMs = 0;
        streaming.queueResult(
          const SegmentResult(confirmedText: 'Hello.', hypothesis: 'Hello.'),
        );

        await coordinator.start();
        await coordinator.stop();

        final committed = events.whereType<SegmentCommitted>();
        expect(committed, isNotEmpty);
        expect(committed.first.text, equals('Hello.'));
      });

      test('falls back to locked prefix when hypothesis regresses mid-word',
          () async {
        final events = <RecordingEvent>[];
        coordinator.events.listen(events.add);
        recorder.frames = [_oneFrame];
        recorder.silenceDurationMs = 0;
        // confirmed prefix establishes lockedText
        streaming.queueResult(
          const OngoingResult(
            confirmedText: 'hello',
            hypothesis: 'world', // does not start with 'hello'
          ),
        );

        await coordinator.start();
        await coordinator.stop();

        final updates = events.whereType<HypothesisUpdated>();
        expect(updates.first.displayText, equals('hello'));
      });
    });

    group('VAD-driven waiting-for-speech', () {
      test(
          'never emits DecodingStarted across multiple silence frames',
          () async {
        // simulates what happens when VAD holds silenceDurationMs > 0 across
        // several frames : the coordinator should skip all frames and never
        // transition out of waiting-for-speech.
        final events = <RecordingEvent>[];
        coordinator.events.listen(events.add);
        recorder.frames = [_oneFrame, _oneFrame, _oneFrame];
        recorder.silenceDurationMs = 600;

        await coordinator.start();
        await coordinator.stop();

        expect(events.whereType<DecodingStarted>(), isEmpty);
      });

      test(
          'advances streaming watermark for each silence frame',
          () async {
        recorder.frames = [_oneFrame, _oneFrame];
        recorder.silenceDurationMs = 300;

        await coordinator.start();
        await coordinator.stop();

        // two frames skipped : lastSkipTo reflects the cumulative watermark.
        expect(streaming.lastSkipTo, equals(2));
      });

    });

    group('silence commit', () {
      test(
          'emits SegmentCommitted after sustained silence following confirmed speech',
          () {
        fakeAsync((fake) {
          final events = <RecordingEvent>[];
          coordinator.events.listen(events.add);

          recorder.frames = [_oneFrame];
          recorder.silenceDurationMs = 0;
          streaming.queueResult(
            const OngoingResult(
              confirmedText: 'hello',
              hypothesis: 'hello world',
            ),
          );

          unawaited(coordinator.start());
          fake.flushMicrotasks(); // complete recorder.start()

          // first tick: active speech, lockedText = 'hello'
          fake.elapse(const Duration(milliseconds: 500));
          fake.flushMicrotasks();

          // second tick: sustained silence, silence commit
          recorder.silenceDurationMs = 5000;
          fake.elapse(const Duration(milliseconds: 500));
          fake.flushMicrotasks();

          final committed = events.whereType<SegmentCommitted>();
          expect(committed, isNotEmpty);
          // hypothesis extends lockedText, so _bestCommitText returns the full hypothesis
          expect(committed.first.text, equals('hello world'));
          expect(streaming.commitCalls, greaterThanOrEqualTo(1));
        });
      });

      test('uses lockedText when hypothesis does not cleanly extend it', () {
        fakeAsync((fake) {
          final events = <RecordingEvent>[];
          coordinator.events.listen(events.add);

          recorder.frames = [_oneFrame];
          recorder.silenceDurationMs = 0;
          streaming.queueResult(
            const OngoingResult(
              confirmedText: 'hello',
              hypothesis: 'different', // does not start with lockedText
            ),
          );

          unawaited(coordinator.start());
          fake.flushMicrotasks();

          fake.elapse(const Duration(milliseconds: 500));
          fake.flushMicrotasks();

          recorder.silenceDurationMs = 5000;
          fake.elapse(const Duration(milliseconds: 500));
          fake.flushMicrotasks();

          final committed = events.whereType<SegmentCommitted>().first;
          expect(committed.text, equals('hello'));
        });
      });
    });

    group('dispose', () {
      test('closes the event stream', () async {
        var done = false;
        coordinator.events.listen(null, onDone: () => done = true);

        coordinator.dispose();
        await Future<void>.value();

        expect(done, isTrue);
      });
    });
  });

  group('RecordingCoordinator error handling', () {
    late _FakeRecorder recorder;
    late _FakeStreaming streaming;
    late RecordingCoordinator coordinator;

    setUp(() {
      recorder = _FakeRecorder();
      streaming = _FakeStreaming();
      coordinator = RecordingCoordinator(
        recorder: recorder,
        streaming: streaming,
      );
    });

    tearDown(() => coordinator.dispose());

    test('emits DecodingFinished then RecordingFailed when process throws',
        () async {
      final error = StateError('encoder failed');
      streaming.queueError(error);
      recorder.frames = [_oneFrame];

      final events = <RecordingEvent>[];
      coordinator.events.listen(events.add);

      await coordinator.start();
      await coordinator.stop();

      final finishedIdx = events.indexWhere((e) => e is DecodingFinished);
      final failedIdx = events.indexWhere((e) => e is RecordingFailed);
      expect(finishedIdx, lessThan(failedIdx));
      final failed = events.whereType<RecordingFailed>().single;
      expect(failed.error, same(error));
    });

    test('emits exactly one RecordingFailed per failure', () async {
      streaming.queueError(StateError('forced failure'));
      recorder.frames = [_oneFrame];

      final events = <RecordingEvent>[];
      coordinator.events.listen(events.add);

      await coordinator.start();
      await coordinator.stop();

      expect(events.whereType<RecordingFailed>(), hasLength(1));
    });

    test('resets streaming service when failure occurs', () async {
      streaming.queueError(StateError('forced failure'));
      recorder.frames = [_oneFrame];

      await coordinator.start();
      await coordinator.stop();

      // start() calls reset once; _stopSession() calls reset again on failure
      expect(streaming.resetCalls, equals(2));
    });

    test('no further events are emitted after RecordingFailed from a timer tick',
        () {
      fakeAsync((fake) {
        streaming.queueError(StateError('forced failure'));
        recorder.frames = [_oneFrame];

        final events = <RecordingEvent>[];
        coordinator.events.listen(events.add);

        unawaited(coordinator.start());
        fake.elapse(const Duration(milliseconds: 500));
        fake.flushMicrotasks();

        // failure fired during the timer tick
        expect(events.whereType<RecordingFailed>(), hasLength(1));

        // advance further, timer should be stopped, no new events
        fake.elapse(const Duration(milliseconds: 2000));
        fake.flushMicrotasks();

        expect(events.whereType<RecordingFailed>(), hasLength(1));
        expect(events.whereType<DecodingStarted>(), hasLength(1));
      });
    });

    test(
        'RecordingFailed carries a PipelineStageException when real streaming '
        'service wraps an encode failure', () async {
      final cause = StateError('onnx session failed');
      final realStreaming = StreamingTranscriptionService(
        encode: (_) async => throw cause,
        decoder: const DecoderService(blankId: 0),
        textService: const StubTokenIdToTextService(),
      );
      final realCoordinator = RecordingCoordinator(
        recorder: recorder,
        streaming: realStreaming,
      );
      recorder.frames = [_oneFrame];

      final events = <RecordingEvent>[];
      realCoordinator.events.listen(events.add);

      await realCoordinator.start();
      await realCoordinator.stop();
      realCoordinator.dispose();

      final failed = events.whereType<RecordingFailed>().single;
      expect(failed.error, isA<PipelineStageException>());
      final pse = failed.error as PipelineStageException;
      expect(pse.stage, equals('encode'));
      expect(pse.cause, same(cause));
      expect(pse.stackTrace, isNotNull);
    });
    test(
        'RecordingFailed carries a PipelineStageException with stage "decode" '
        'when decoder receives mismatched logProbs', () async {
      final realStreaming = StreamingTranscriptionService(
        encode: (_) async => (
          List<double>.filled(10, 0.0),
          [1, 2, 3], // expects 6 values, not 10, decoder throws
          null,
        ),
        decoder: const DecoderService(blankId: 0),
        textService: const StubTokenIdToTextService(),
      );
      final realCoordinator = RecordingCoordinator(
        recorder: recorder,
        streaming: realStreaming,
      );
      recorder.frames = [_oneFrame];

      final events = <RecordingEvent>[];
      realCoordinator.events.listen(events.add);

      await realCoordinator.start();
      await realCoordinator.stop();
      realCoordinator.dispose();

      final failed = events.whereType<RecordingFailed>().single;
      final pse = failed.error as PipelineStageException;
      expect(pse.stage, equals('decode'));
      expect(pse.stackTrace, isNotNull);
    });

    test(
        'RecordingFailed carries a PipelineStageException with stage "tokenise" '
        'when text service throws', () async {
      final realStreaming = StreamingTranscriptionService(
        encode: _validEncode,
        decoder: const DecoderService(blankId: 0),
        textService: _ThrowingTextService(),
      );
      final realCoordinator = RecordingCoordinator(
        recorder: recorder,
        streaming: realStreaming,
      );
      recorder.frames = [_oneFrame];

      final events = <RecordingEvent>[];
      realCoordinator.events.listen(events.add);

      await realCoordinator.start();
      await realCoordinator.stop();
      realCoordinator.dispose();

      final failed = events.whereType<RecordingFailed>().single;
      final pse = failed.error as PipelineStageException;
      expect(pse.stage, equals('tokenise'));
      expect(pse.stackTrace, isNotNull);
    });
  });
}

Future<(List<double>, List<int>, TransformerDecoderRunner?)> _validEncode(
  List<Float32List> _,
) async =>
    (
      const <double>[
        -100, 0, -100,
        0, -100, -100,
        -100, -100, 0,
      ],
      const <int>[3, 3],
      null,
    );

class _ThrowingTextService implements TokenIdToTextService {
  @override
  Future<DecodeResult> decode(Int32List tokenIds) async =>
      throw StateError('tokenise failed');
}
