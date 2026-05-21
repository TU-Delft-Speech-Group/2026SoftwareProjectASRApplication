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
  int? _carryByte;

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
    _carryByte = null;
    final stream = await _recorder.startStream(recordStreamConfig);
    stream.listen(
      (Uint8List bytes) {
        final Uint8List aligned;
        if (_carryByte != null) {
          aligned = Uint8List(bytes.length + 1)
            ..[0] = _carryByte!
            ..setRange(1, bytes.length + 1, bytes);
          _carryByte = null;
        } else {
          aligned = bytes;
        }

        final usableLength = aligned.length - (aligned.length.isOdd ? 1 : 0);
        if (aligned.length.isOdd) {
          _carryByte = aligned[aligned.length - 1];
        }

        final data = ByteData.sublistView(aligned, 0, usableLength);
        final int16Entries = Int16List(usableLength ~/ 2);
        for (var i = 0; i < int16Entries.length; i++) {
          int16Entries[i] = data.getInt16(i * 2, Endian.little);
        }

        final normalized = int16Entries
            .map((v) => v.toDouble() / 32768.0)
            .toList();

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
    _frames.addAll(_windowingService.stop());
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    _frames = [];
  }
}
