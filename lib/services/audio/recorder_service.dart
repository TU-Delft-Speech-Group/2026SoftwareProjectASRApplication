import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../Exceptions/Audio/microphone_permission_denied_exception.dart';

final recordStreamConfig = RecordConfig(
  encoder: AudioEncoder.pcm16bits,
  sampleRate: 16_000,
  numChannels: 1,
  autoGain: true,
  echoCancel: true,
  noiseSuppress: true,
);

class RecorderService {
  final AudioRecorder _recorder;
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  RecorderService(this._recorder);

  Future<void> start() async {
    if (!await _recorder.hasPermission(request: false)) {
      throw MicrophonePermissionDeniedException();
    }

    _isRecording = true;
    final stream = await _recorder.startStream(recordStreamConfig);
    stream.listen(
      (Uint8List bytes) {
        // final int16Entries = Int16List.view(
        //   bytes.buffer,
        //   bytes.offsetInBytes,
        //   bytes.lengthInBytes ~/ 2,
        // );
      },
      onDone: () {
        _isRecording = false;
      },
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    await _recorder.stop();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
