import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:asr_application/services/audio/vad_service.dart';
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
  // Fallback peak amplitude threshold used when no [VadService] is provided.
  // 400 ≈ 1.2 % of int16 full scale. The original value of 1500 was set for
  // normative speech and risks silencing low-intensity or breathy speech.
  // 400 sits above typical smartphone noise floor (100-300) while
  // reducing that risk.
  static const int _silenceThresholdPeak = 400;
  // Each chunk from the record plugin holds ~100ms of audio at 16kHz mono.
  static const int _chunkDurationMs = 100;

  final AudioRecorder _recorder;
  final VadService? _vadService;
  late final WindowingService _windowingService;
  List<SampleWindow> _frames = [];
  List<SampleWindow> get frames => _frames;

  /// Raw continuous PCM samples (no windowing). Engines like Whisper
  /// that compute their own features read from this buffer.
  ///
  /// Only the most recent [maxRawPcmSeconds] are kept, so long sessions do
  /// not grow memory; [rawPcmOffset] is the absolute index (since start) of
  /// rawPcm[0].
  final List<double> _rawPcm = [];
  List<double> get rawPcm => _rawPcm;
  int _rawPcmOffset = 0;
  int get rawPcmOffset => _rawPcmOffset;
  final int maxRawPcmSeconds;
  int? _carryByte;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  int _silentChunkCount = 0;
  int get silenceDurationMs => _silentChunkCount * _chunkDurationMs;

  bool _speechSinceLastCheck = false;

  /// True when any chunk since the previous call contained speech. Reading
  /// consumes the flag, so each caller observes only its own window.
  ///
  /// Unlike [silenceDurationMs] (which reflects the most recent chunk only),
  /// this catches speech bursts that don't align with the caller's cadence —
  /// e.g. a word spoken mid-tick whose volume dips again before the tick ends.
  bool takeSpeechSinceLastCheck() {
    final hadSpeech = _speechSinceLastCheck;
    _speechSinceLastCheck = false;
    return hadSpeech;
  }

  // Ensures VAD inference runs sequentially even though stream chunks may
  // arrive while the previous inference is still in flight.
  Future<void> _processChain = Future.value();

  RecorderService(
    this._recorder, {
    VadService? vadService,
    WindowingService? windowingService,
    this.maxRawPcmSeconds = 30,
  }) : _vadService = vadService,
       _windowingService = windowingService ?? WindowingService();

  Future<void> initialize() async {
    await _vadService?.initialize();
  }

  Future<void> start() async {
    if (!await _recorder.hasPermission(request: false)) {
      throw MicrophonePermissionDeniedException();
    }

    await _vadService?.reset();

    _isRecording = true;
    _frames = [];
    _rawPcm.clear();
    _rawPcmOffset = 0;
    _carryByte = null;
    _silentChunkCount = 0;
    _speechSinceLastCheck = false;
    _processChain = Future.value();

    final stream = await _recorder.startStream(recordStreamConfig);
    stream.listen(
      (Uint8List bytes) {
        _processChain = _processChain.then((_) => _processChunk(bytes)).catchError((Object e, StackTrace st) {
          dev.log('error processing chunk', error: e, stackTrace: st, name: 'RecorderService');
        });
      },
      onDone: () {
        _isRecording = false;
      },
      cancelOnError: false,
    );
  }

  Future<void> drainProcessing() => _processChain;

  Future<void> stop() async {
    await _recorder.stop();
    try {
      await _processChain;
    } catch (e, st) {
      dev.log('error draining process chain on stop', error: e, stackTrace: st, name: 'RecorderService');
    }
    _silentChunkCount = 0;
    _frames.addAll(_windowingService.stop());
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    await _vadService?.dispose();
    _frames = [];
  }

  Future<void> _processChunk(Uint8List bytes) async {
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

    final normalized = int16Entries.map((v) => v.toDouble() / 32768.0).toList();

    final vad = _vadService;
    final bool isSpeech;
    if (vad != null) {
      isSpeech = await vad.isSpeech(normalized);
    } else {
      isSpeech = peak >= _silenceThresholdPeak;
    }
    if (isSpeech) {
      _silentChunkCount = 0;
      _speechSinceLastCheck = true;
    } else {
      _silentChunkCount++;
    }

    _rawPcm.addAll(normalized);
    // Trim in blocks (keep max, drop when 1.5x) so removeRange runs rarely.
    final keep = maxRawPcmSeconds * 16000;
    if (_rawPcm.length > keep + keep ~/ 2) {
      final drop = _rawPcm.length - keep;
      _rawPcm.removeRange(0, drop);
      _rawPcmOffset += drop;
    }
    final frames = _windowingService.addSamples(normalized);
    _frames.addAll(frames);
  }
}
