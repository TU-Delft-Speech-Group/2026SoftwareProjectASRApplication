import 'package:asr_application/Exceptions/Audio/microphone_permission_denied_exception.dart';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

@GenerateNiceMocks([MockSpec<AudioRecorder>()])
import 'recorder_service_test.mocks.dart';

void main() {
  late MockAudioRecorder recorder;
  late RecorderService service;

  setUp(() async {
    recorder = MockAudioRecorder();
    service = RecorderService(recorder);
    when(recorder.hasPermission(request: false)).thenAnswer((_) async => true);
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
      await recorder.stop();
      await Future<void>.delayed(Duration.zero);
      expect(service.isRecording, isFalse);
    });
  });
}
