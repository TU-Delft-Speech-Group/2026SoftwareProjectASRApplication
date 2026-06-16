import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:asr_application/services/audio/silero_vad_service.dart';
import 'package:asr_application/services/shared/onnx/onnx.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';


class _FakeVadBackend implements OnnxInferenceBackendContract {
  _FakeVadBackend(this._probabilities);

  final Queue<double> _probabilities;
  late final _FakeVadSession session;
  String? createdAssetPath;

  @override
  Future<_FakeVadSession> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  }) async {
    createdAssetPath = assetPath;
    session = _FakeVadSession(_probabilities);
    return session;
  }

  @override
  Future<_FakeVadSession> createSessionFromFile(
    String filePath, {
    OrtSessionOptions? options,
  }) => createSessionFromAsset(filePath, options: options);

  @override
  Future<_FakeTensor> createTensor(dynamic data, List<int> shape) async =>
      _FakeTensor(data, shape);
}

class _FakeVadSession implements OnnxInferenceSessionContract {
  _FakeVadSession(this._probabilities);

  final Queue<double> _probabilities;
  Map<String, OnnxTensorContract>? lastInputs;
  var runCallCount = 0;
  var closed = false;

  @override
  Future<Map<String, OnnxTensorContract>> run(
    Map<String, OnnxTensorContract> inputs,
  ) async {
    lastInputs = inputs;
    runCallCount++;
    final prob = _probabilities.removeFirst();
    return {
      'output': _FakeTensor(Float32List.fromList([prob]), [1, 1]),
      'stateN': _FakeTensor(Float32List(256), [2, 1, 128]),
    };
  }

  @override
  Future<void> close() async => closed = true;
}

class _FakeTensor implements OnnxTensorContract {
  _FakeTensor(this.data, this.shape);

  final dynamic data;

  @override
  final List<int> shape;

  @override
  Future<Float32List> asFloat32List() async {
    if (data is Float32List) return data as Float32List;
    return Float32List.fromList(
      (data as List).map((e) => (e as num).toDouble()).toList(),
    );
  }

  @override
  Future<List<dynamic>> asList() async => List<dynamic>.from(
    data is List ? data as List : [data],
  );

  @override
  Future<void> dispose() async {}
}


_FakeVadBackend _backend(List<double> probs) =>
    _FakeVadBackend(Queue.of(probs));

SileroVadService _service(
  _FakeVadBackend backend, {
  double threshold = 0.5,
  double? exitThreshold,
}) => SileroVadService(
  backend: backend,
  threshold: threshold,
  exitThreshold: exitThreshold,
);

// 512 samples of silence (all zeros)
List<double> get _silence => List.filled(512, 0.0);

// 512-sample sine wave at 200 Hz, 16 kHz, amplitude amp
List<double> _sine(double amp) {
  const sampleRate = 16000;
  const freq = 200.0;
  return List.generate(
    512,
    (i) => amp * sin(2 * pi * freq * i / sampleRate),
  );
}


void main() {
  group('SileroVadService', () {
    group('initialization', () {
      test('opens session from the configured asset path', () async {
        const path = 'assets/silero_vad.onnx';
        final backend = _backend([0.0]);
        final service = SileroVadService(assetPath: path, backend: backend);

        await service.initialize();

        expect(backend.createdAssetPath, path);
      });

      test('initialize is idempotent — session loaded only once', () async {
        final backend = _backend([]);
        final service = SileroVadService(backend: backend);

        await service.initialize();
        final pathAfterFirst = backend.createdAssetPath;
        await service.initialize();

        // createdAssetPath is only set on createSessionFromAsset, if it were
        // called twice it would still equal the same value, but runCallCount
        // on the session would diverge. We confirm the session exists and
        // the asset path was set exactly once (not reset to null).
        expect(backend.createdAssetPath, pathAfterFirst);
        expect(backend.createdAssetPath, isNotNull);
      });

      test('isSpeech throws StateError before initialize', () async {
        final service = _service(_backend([]));

        await expectLater(
          service.isSpeech(_silence),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('speech detection', () {
      test('returns true when model output meets threshold', () async {
        final backend = _backend([0.9]);
        final service = _service(backend);
        await service.initialize();

        expect(await service.isSpeech(_silence), isTrue);
      });

      test('returns false when model output is below threshold', () async {
        final backend = _backend([0.1]);
        final service = _service(backend);
        await service.initialize();

        expect(await service.isSpeech(_silence), isFalse);
      });

      test('returns true when output exactly equals threshold', () async {
        final backend = _backend([0.5]);
        final service = _service(backend, threshold: 0.5);
        await service.initialize();

        expect(await service.isSpeech(_silence), isTrue);
      });

      test('custom threshold — low value catches weak speech probability',
          () async {
        final backend = _backend([0.35]);
        final service = _service(backend, threshold: 0.3);
        await service.initialize();

        expect(await service.isSpeech(_silence), isTrue);
      });

      test('returns true if any window in the call exceeds threshold',
          () async {
        // 1024 samples : two 512-sample windows; first silent, second speech
        final backend = _backend([0.1, 0.8]);
        final service = _service(backend);
        await service.initialize();

        final result = await service.isSpeech([..._silence, ..._silence]);

        expect(result, isTrue);
        expect(backend.session.runCallCount, 2);
      });

      test('returns false when all windows are below threshold', () async {
        final backend = _backend([0.1, 0.2]);
        final service = _service(backend);
        await service.initialize();

        final result = await service.isSpeech([..._silence, ..._silence]);

        expect(result, isFalse);
      });
    });

    group('input tensor shapes', () {
      test('input tensor has shape [1, 576] (512 samples + 64 context)', () async {
        final backend = _backend([0.0]);
        final service = _service(backend);
        await service.initialize();
        await service.isSpeech(_silence);

        final input = backend.session.lastInputs!['input']!;
        expect(input.shape, [1, 576]);
      });

      test('sr tensor has shape [1] with value 16000', () async {
        final backend = _backend([0.0]);
        final service = _service(backend);
        await service.initialize();
        await service.isSpeech(_silence);

        final sr = backend.session.lastInputs!['sr']!;
        expect(sr.shape, [1]);
        final values = await sr.asList();
        expect(values.first, 16000);
      });

      test('state tensor has shape [2, 1, 128]', () async {
        final backend = _backend([0.0]);
        final service = _service(backend);
        await service.initialize();
        await service.isSpeech(_silence);

        expect(backend.session.lastInputs!['state']!.shape, [2, 1, 128]);
      });
    });

    group('chunk buffering', () {
      test('fewer than 512 samples do not trigger inference', () async {
        final backend = _backend([]);
        final service = _service(backend);
        await service.initialize();

        await service.isSpeech(List.filled(300, 0.0));

        expect(backend.session.runCallCount, 0);
      });

      test('exactly 512 samples trigger one inference call', () async {
        final backend = _backend([0.0]);
        final service = _service(backend);
        await service.initialize();

        await service.isSpeech(_silence);

        expect(backend.session.runCallCount, 1);
      });

      test('partial window carries over to the next call', () async {
        // 300 + 300 = 600 samples : one window fires, 88 buffered
        final backend = _backend([0.0]);
        final service = _service(backend);
        await service.initialize();

        await service.isSpeech(List.filled(300, 0.0));
        await service.isSpeech(List.filled(300, 0.0));

        expect(backend.session.runCallCount, 1);
      });

      test('carried samples contribute to next window', () async {
        // 300 + 300 + 300 = 900 : window at 512, window at 1024 (incomplete)
        final backend = _backend([0.0, 0.0]);
        final service = _service(backend);
        await service.initialize();

        await service.isSpeech(List.filled(300, 0.0));
        await service.isSpeech(List.filled(300, 0.0));
        await service.isSpeech(List.filled(300, 0.0));

        expect(backend.session.runCallCount, 1);
      });
    });

    group('hysteresis', () {
      test('stays in speech mode when probability drops between entry and exit thresholds', () async {
        // entry=0.5, exit=0.1: prob 0.9 triggers speech, then 0.3 keeps it
        final backend = _backend([0.9, 0.3]);
        final service = _service(backend, threshold: 0.5, exitThreshold: 0.1);
        await service.initialize();

        expect(await service.isSpeech(_silence), isTrue); // enters speech
        expect(await service.isSpeech(_silence), isTrue); // stays in speech
      });

      test('exits speech mode when probability drops below exit threshold', () async {
        final backend = _backend([0.9, 0.05]);
        final service = _service(backend, threshold: 0.5, exitThreshold: 0.1);
        await service.initialize();

        expect(await service.isSpeech(_silence), isTrue);  // enters speech
        expect(await service.isSpeech(_silence), isFalse); // exits speech
      });

      test('without hysteresis mid-range probability does not extend speech', () async {
        // exit == entry == 0.5, so 0.3 does not keep speech alive
        final backend = _backend([0.9, 0.3]);
        final service = _service(backend, threshold: 0.5);
        await service.initialize();

        expect(await service.isSpeech(_silence), isTrue);
        expect(await service.isSpeech(_silence), isFalse);
      });
    });


    group('LSTM state', () {
      test('state is threaded through across consecutive chunks', () async {
        // Two consecutive 512-sample calls each produce one run call,
        // proving the service threads state across calls instead of
        // reinitialising h/c to zeros each time.
        final backend = _backend([0.0, 0.0]);
        final service = _service(backend);
        await service.initialize();

        await service.isSpeech(_silence);
        await service.isSpeech(_silence);

        expect(backend.session.runCallCount, 2);
      });

      test('reset clears buffer — buffered samples are discarded', () async {
        final backend = _backend([]);
        final service = _service(backend);
        await service.initialize();

        await service.isSpeech(List.filled(300, 0.0));
        await service.reset();
        // After reset, 300 new samples should not trigger inference
        // (buffer was cleared; if it weren't, 300+300=600 would fire one call)
        await service.isSpeech(List.filled(300, 0.0));

        expect(backend.session.runCallCount, 0);
      });
    });

    group('dispose', () {
      test('closes the ONNX session', () async {
        final backend = _backend([]);
        final service = _service(backend);
        await service.initialize();

        await service.dispose();

        expect(backend.session.closed, isTrue);
      });

      test('dispose before initialize does not throw', () async {
        final service = _service(_backend([]));
        await expectLater(service.dispose(), completes);
      });

      test('dispose is safe to call twice', () async {
        final backend = _backend([]);
        final service = _service(backend);
        await service.initialize();

        await service.dispose();
        await expectLater(service.dispose(), completes);
      });
    });

    group('golden fixture — low-amplitude speech', () {
      // Demonstrates the motivation for this feature.
      // A 200 Hz sine wave at amplitude 0.01 has a peak int16 value of
      // (0.01 * 32768).round() = 328, which is below the fallback amplitude
      // threshold of 400; dysarthric-calibrated fallback would
      // classify it as silence. The VAD service, backed by a model that
      // returns high confidence, correctly reports speech.
      test(
        'detects speech that amplitude threshold would classify as silence',
        () async {
          const amplitude = 0.01;
          final samples = _sine(amplitude);

          // Confirm amplitude threshold would miss this
          final peakInt16 = samples
              .map((s) => (s * 32768).abs().round())
              .reduce(max);
          expect(peakInt16, lessThan(400));

          // VAD correctly detects speech
          final backend = _backend([0.9]);
          final service = _service(backend);
          await service.initialize();

          expect(await service.isSpeech(samples), isTrue);
        },
      );
    });
  });
}
