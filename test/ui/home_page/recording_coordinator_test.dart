import 'dart:async';
import 'dart:typed_data';

import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';
import 'package:asr_application/ui/home/view_models/recording_coordinator.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRecorder implements RecorderService {
  @override
  var frames = <SampleWindow>[];
  @override
  var silenceDurationMs = 0;
  var startCalls = 0;
  var stopCalls = 0;

  @override
  bool get isRecording => startCalls > stopCalls;

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
  var resetCalls = 0;
  var commitCalls = 0;
  int? lastSkipTo;

  void queueResult(StreamResult? result) => _results.add(result);

  @override
  int get maxBufferFrames => 1500;

  @override
  int get bufferLength => 0;

  @override
  Future<StreamResult?> process(List<Float32List> allFrames) async =>
      _results.isNotEmpty ? _results.removeAt(0) : null;

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
}
