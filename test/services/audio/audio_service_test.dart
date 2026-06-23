import 'dart:async';
import 'dart:typed_data';

import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

import '../../../testing/utils/test_helpers.dart';
@GenerateNiceMocks([MockSpec<AudioRecorder>()])
import 'recorder_service_test.mocks.dart';

void main() {
  const epsilon = 1e-4;

  group('Audio Service', () {
    late MockAudioRecorder recorder;
    late RecorderService service;
    late StreamController<Uint8List> streamController;

    setUp(() async {
      recorder = MockAudioRecorder();
      streamController = StreamController<Uint8List>();
      service = RecorderService(recorder);
      when(
        recorder.hasPermission(request: false),
      ).thenAnswer((_) async => true);
      when(
        recorder.startStream(any),
      ).thenAnswer((_) async => streamController.stream);
      when(recorder.stop()).thenAnswer((_) async {
        await streamController.close();
        return null;
      });
    });

    tearDown(() {
      if (!streamController.isClosed) {
        streamController.close();
      }
    });

    test('Poisoned Potato WAV to Mel Spectogram', () async {
      final pcm16 = await wavToPcm16('testing/assets/poisoned_potato_test.wav');
      final chunks = 20;
      final chunkSize = pcm16.length ~/ chunks;

      await service.start();
      for (int i = 0; i < chunks; i++) {
        final start = i * chunkSize;
        final end = i == chunks - 1 ? pcm16.length : (i + 1) * chunkSize;
        streamController.add(pcm16.sublist(start, end));
      }
      await service.stop();

      final melFrames = service.frames.map((s) => s.melEnergies).toList();
      expect(melFrames, isNotEmpty);
      expect(melFrames, everyElement(hasLength(80)));

      final expected = await jsonToMatrix(
        'test/services/audio/golden/espnet_mel_spectrogram_tests_poisoned_potato_test_wav.json',
      );
      expectMatrixClose(melFrames, expected, epsilon);
    });
  });
}
