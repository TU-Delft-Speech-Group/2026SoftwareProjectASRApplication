import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/ui/home/view_models/recording_coordinator.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:record/record.dart';

import 'latency_result.dart';

const _sampleRate = 16000;
const _bundledAsset = 'assets/latency/jfk_sample.wav';

// Streams the bundled public-domain sample straight through the runtime's
// streaming service, timing each process() call (encode + decode). No mic, no
// coordinator: deterministic and repeatable across phones.
Future<LatencyResult> runBundledLatency(
  AsrRuntime runtime, {
  int chunkMs = 500,
}) async {
  final streaming = runtime.streamingService;
  streaming.reset();

  final bytes = (await rootBundle.load(_bundledAsset)).buffer.asUint8List();
  final samples = _decodeWavToFloats(bytes);
  final audioMs = samples.length / _sampleRate * 1000.0;

  final windowing = WindowingService();
  final chunkSamples = _sampleRate * chunkMs ~/ 1000;
  final frames = <Float32List>[];
  final perChunk = <double>[];
  int? firstResponseMs;
  var totalProcessMs = 0.0;
  final wall = Stopwatch()..start();

  for (var off = 0; off < samples.length; off += chunkSamples) {
    final end = min(off + chunkSamples, samples.length);
    final isLast = end >= samples.length;
    final windows = windowing.addSamples(
      samples.sublist(off, end),
      flush: isLast,
    );
    for (final w in windows) {
      frames.add(Float32List.fromList(w.melEnergies));
    }

    final t = Stopwatch()..start();
    final result = await streaming.process(frames);
    t.stop();
    final ms = t.elapsedMicroseconds / 1000.0;
    perChunk.add(ms);
    totalProcessMs += ms;

    if (firstResponseMs == null &&
        result != null &&
        result.hypothesis.isNotEmpty) {
      firstResponseMs = wall.elapsedMilliseconds;
    }
  }
  wall.stop();

  return LatencyResult(
    label: 'Bundled sample (JFK, 11s)',
    audioMs: audioMs,
    totalProcessMs: totalProcessMs,
    perChunkMs: perChunk,
    firstResponseMs: firstResponseMs,
    transcript: streaming.confirmedText,
  );
}

// A live mic-driven measurement. Drives the real RecorderService +
// RecordingCoordinator (the production path) and times each decode tick via the
// coordinator's DecodingStarted/DecodingFinished events.
class LiveLatencySession {
  LiveLatencySession(this._runtime);

  final AsrRuntime _runtime;
  RecorderService? _recorder;
  RecordingCoordinator? _coordinator;
  StreamSubscription<RecordingEvent>? _sub;

  final List<double> _perChunk = [];
  int? _firstResponseMs;
  Stopwatch? _wall;
  Stopwatch? _decodeTimer;

  Future<void> start() async {
    _runtime.streamingService.reset();
    final recorder = RecorderService(
      AudioRecorder(),
      vadService: _runtime.vadService,
    );
    final coordinator = RecordingCoordinator(
      recorder: recorder,
      streaming: _runtime.streamingService,
    );
    _recorder = recorder;
    _coordinator = coordinator;

    _wall = Stopwatch()..start();
    _sub = coordinator.events.listen((event) {
      switch (event) {
        case DecodingStarted():
          _decodeTimer = Stopwatch()..start();
        case DecodingFinished():
          final t = _decodeTimer;
          if (t != null) {
            t.stop();
            _perChunk.add(t.elapsedMicroseconds / 1000.0);
            _decodeTimer = null;
          }
        case HypothesisUpdated():
          _firstResponseMs ??= _wall!.elapsedMilliseconds;
        default:
          break;
      }
    });

    await coordinator.initialize();
    await coordinator.start();
  }

  Future<LatencyResult> stop() async {
    final wall = _wall!;
    final transcript = await _coordinator!.stop();
    wall.stop();
    await _sub?.cancel();
    _coordinator!.dispose();
    await _recorder!.dispose();

    return LatencyResult(
      label: 'Live mic',
      audioMs: wall.elapsedMilliseconds.toDouble(),
      totalProcessMs: _perChunk.fold(0.0, (a, b) => a + b),
      perChunkMs: List.of(_perChunk),
      firstResponseMs: _firstResponseMs,
      transcript: transcript,
    );
  }
}

// Minimal WAV (PCM16 mono) decoder: locates the 'data' chunk and normalises
// int16 samples to [-1, 1].
List<double> _decodeWavToFloats(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  var offset = 12; // skip 'RIFF' <size> 'WAVE'
  var dataStart = 44;
  var dataLen = bytes.length - 44;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = view.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      dataStart = offset + 8;
      dataLen = size;
      break;
    }
    offset += 8 + size + (size & 1); // chunks are word-aligned
  }
  final end = min(dataStart + dataLen, bytes.length);
  final count = (end - dataStart) ~/ 2;
  final out = List<double>.filled(count, 0);
  for (var i = 0; i < count; i++) {
    out[i] = view.getInt16(dataStart + i * 2, Endian.little) / 32768.0;
  }
  return out;
}
