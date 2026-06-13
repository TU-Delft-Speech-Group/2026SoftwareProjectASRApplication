import 'dart:async';
import 'dart:typed_data';

import 'package:asr_application/exceptions/audio/microphone_permission_denied_exception.dart';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

import '../../../testing/fakes/services/audio/fake_vad_service.dart';

@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<WindowingService>()])
import 'recorder_service_test.mocks.dart';

Uint8List _pcm16Bytes(List<int> int16Values) =>
    Int16List.fromList(int16Values).buffer.asUint8List();

void main() {
  late MockAudioRecorder recorder;
  late RecorderService service;
  late StreamController<Uint8List> streamController;

  setUp(() async {
    recorder = MockAudioRecorder();
    streamController = StreamController<Uint8List>();
    service = RecorderService(recorder);
    when(recorder.hasPermission(request: false)).thenAnswer((_) async => true);
    when(
      recorder.startStream(any),
    ).thenAnswer((_) async => streamController.stream);
  });

  tearDown(() {
    if (!streamController.isClosed) {
      streamController.close();
    }
  });

  group('RecorderService', () {
    test('start throws when microphone permission is denied', () async {
      when(
        recorder.hasPermission(request: false),
      ).thenAnswer((_) async => false);

      await expectLater(
        service.start(),
        throwsA(isA<MicrophonePermissionDeniedException>()),
      );
    });

    test('start requests a stream', () async {
      await service.start();

      verify(recorder.startStream(any));
      expect(service.isRecording, isTrue);
    });

    test('resets isRecording to false when the stream completes', () async {
      await service.start();
      expect(service.isRecording, isTrue);
      await streamController.close();
      await Future<void>.delayed(Duration.zero);
      expect(service.isRecording, isFalse);
    });

    test('normalizes pcm16 listener values before windowing', () async {
      final windowingService = MockWindowingService();
      service = RecorderService(recorder, windowingService: windowingService);

      await service.start();

      final pcm16 = Int16List.fromList([-32768, -16384, 0, 16384, 32767]);
      streamController.add(pcm16.buffer.asUint8List());
      await Future<void>.delayed(Duration.zero);

      verify(
        windowingService.addSamples([-1.0, -0.5, 0.0, 0.5, 32767 / 32768]),
      ).called(1);
    });
  });

  group('RecorderService — VAD path', () {
    late FakeVadService vad;

    setUp(() {
      vad = FakeVadService();
      service = RecorderService(recorder, vadService: vad);
      when(recorder.hasPermission(request: false)).thenAnswer((_) async => true);
      when(
        recorder.startStream(any),
      ).thenAnswer((_) async => streamController.stream);
    });

    test('start calls vadService.reset()', () async {
      await service.start();

      expect(vad.resetCalls, 1);
    });

    test('silence count increments when VAD returns false', () async {
      vad.queueResponse(false);
      await service.start();

      streamController.add(_pcm16Bytes([100, 200, 300]));
      await Future<void>.delayed(Duration.zero);

      expect(service.silenceDurationMs, 100);
    });

    test('silence count resets to zero when VAD returns true', () async {
      vad
        ..queueResponse(false)
        ..queueResponse(true);
      await service.start();

      streamController.add(_pcm16Bytes([100, 200]));
      await Future<void>.delayed(Duration.zero);
      streamController.add(_pcm16Bytes([100, 200]));
      await Future<void>.delayed(Duration.zero);

      expect(service.silenceDurationMs, 0);
    });

    test('VAD receives the normalised samples', () async {
      vad.queueResponse(true);
      await service.start();

      final pcm16 = Int16List.fromList([16384, -16384]);
      streamController.add(pcm16.buffer.asUint8List());
      await Future<void>.delayed(Duration.zero);

      expect(vad.samplesReceived.single, [0.5, -0.5]);
    });

    test('chunks are processed sequentially when VAD is async', () async {
      vad.queueResponse(false);
      vad.queueResponse(true);

      await service.start();

      streamController.add(_pcm16Bytes([100]));
      streamController.add(_pcm16Bytes([200]));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(vad.samplesReceived.length, 2);
      expect(vad.samplesReceived[0], [100 / 32768]);
      expect(vad.samplesReceived[1], [200 / 32768]);
    });
  });
}
