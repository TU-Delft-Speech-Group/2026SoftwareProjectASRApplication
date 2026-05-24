import 'dart:async';
import 'dart:typed_data';

import 'package:asr_application/exceptions/audio/microphone_permission_denied_exception.dart';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<WindowingService>()])
import 'recorder_service_test.mocks.dart';

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
}
