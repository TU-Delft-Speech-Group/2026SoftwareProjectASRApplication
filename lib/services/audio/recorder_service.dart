import 'dart:async';
import 'dart:typed_data';

import 'package:asr_application/services/audio/windowing_service.dart';
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
  late final WindowingService _windowingService;
  List<SampleWindow> _frames = [];
  List<SampleWindow> get frames => _frames;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  RecorderService(this._recorder, {WindowingService? windowingService})
    : _windowingService = windowingService ?? WindowingService();

  Future<void> start() async {
    if (!await _recorder.hasPermission(request: false)) {
      throw MicrophonePermissionDeniedException();
    }

    _isRecording = true;
    _frames = [];
    final stream = await _recorder.startStream(recordStreamConfig);
    stream.listen(
      (Uint8List bytes) {
        // Convert for unsigned 8 bit to signed 16 bit.
        final data = ByteData.sublistView(bytes);
        final int16Entries = Int16List(bytes.lengthInBytes ~/ 2);
        for (var i = 0; i < int16Entries.length; i++) {
          int16Entries[i] = data.getInt16(i * 2, Endian.little);
        }

        // Normalize the values to be in range [-1.0, 1.0].
        const maxInt16 = 32768.0; // 2^15
        final normalized = int16Entries
            .map((v) => v.toDouble() / maxInt16)
            .toList();

        // Parse the normalized values to the windowing service and store the frames in a stream.
        final frames = _windowingService.addSamples(normalized);
        _frames.addAll(frames);
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
    _frames = [];
  }
}
