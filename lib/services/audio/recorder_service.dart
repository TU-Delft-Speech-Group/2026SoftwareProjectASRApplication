import 'dart:async';
import 'dart:typed_data';

import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:record/record.dart';

import '../../exceptions/audio/microphone_permission_denied_exception.dart';

// autoGain, echoCancel, noiseSuppress are intentionally disabled. On macOS
// they route the input through voice-call style processing that clips most
// speech content to near-silence, which the ASR encoder reads as blank.
final recordStreamConfig = RecordConfig(
  encoder: AudioEncoder.pcm16bits,
  sampleRate: 16_000,
  numChannels: 1,
  autoGain: false,
  echoCancel: false,
  noiseSuppress: false,
);

class RecorderService {
  // Peak int16 amplitude below which a chunk is considered silence.
  // Raised to 1500 (~4.6 % of full scale) so typical laptop background noise
  // (fans, room tone) is classified as silence; normal speech peaks well above
  // this value. Tune down if soft speakers are cut off too early.
  static const int _silenceThresholdPeak = 1500;
  // Each chunk from the record plugin holds ~100ms of audio at 16kHz mono.
  static const int _chunkDurationMs = 100;

  final AudioRecorder _recorder;
  late final WindowingService _windowingService;
  List<SampleWindow> _frames = [];
  List<SampleWindow> get frames => _frames;
  int? _carryByte;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  int _silentChunkCount = 0;
  int get silenceDurationMs => _silentChunkCount * _chunkDurationMs;

  RecorderService(this._recorder, {WindowingService? windowingService})
    : _windowingService = windowingService ?? WindowingService();

  Future<void> start() async {
    if (!await _recorder.hasPermission(request: false)) {
      throw MicrophonePermissionDeniedException();
    }

    _isRecording = true;
    _frames = [];
    _carryByte = null;
    _silentChunkCount = 0;
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
        var peak = 0;
        for (var i = 0; i < int16Entries.length; i++) {
          final sample = data.getInt16(i * 2, Endian.little);
          int16Entries[i] = sample;
          final abs = sample < 0 ? -sample : sample;
          if (abs > peak) peak = abs;
        }
        if (peak < _silenceThresholdPeak) {
          _silentChunkCount++;
        } else {
          _silentChunkCount = 0;
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
