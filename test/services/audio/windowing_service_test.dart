import 'package:asr_application/Exceptions/Audio/window_function_size_incompatible_exception.dart';
import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final WindowingService service = WindowingService();

  List<double> samples(int length, [double value = 0.25]) =>
      List<double>.filled(length, value);

  setUp(() {
    service.reset();
  });

  group('WindowingService', () {
    test('does not emit a frame before the window length is reached', () {
      final frames = service.addSamples(samples(service.windowLength - 1));

      expect(frames, isEmpty);
    });

    test('emits one frame when the window length is reached exactly', () {
      final frames = service.addSamples(samples(service.windowLength));

      expect(frames, hasLength(1));
      expect(frames.single, isA<SampleWindow>());
    });

    test('emits one frame when more than windowLength', () {
      final frames = service.addSamples(samples(service.windowLength + 10));

      expect(frames, hasLength(1));
      expect(frames.single, isA<SampleWindow>());
    });

    test('emits 3 frame when size is window length + 2* hop length', () {
      final frames = service.addSamples(
        samples(service.windowLength + 2 * service.hopLength),
      );

      expect(frames, hasLength(3));
    });

    test('stop flushes a final padded frame when buffered samples remain', () {
      final initialFrames = service.addSamples(
        samples(service.windowLength + 1),
      );
      final flushedFrames = service.stop();

      expect(initialFrames, hasLength(1));
      expect(flushedFrames, hasLength(1));
    });

    test('reset discards buffered samples', () {
      service.addSamples(samples(service.windowLength - 1));

      service.reset();

      final frames = service.addSamples(samples(service.windowLength - 1));
      expect(frames, isEmpty);
    });

    test('throws when window function size does not match window length', () {
      expect(
        () => _InvalidWindowFunctionWindowingService(),
        throwsA(isA<WindowFunctionSizeIncompatibleException>()),
      );
    });
  });
}

class _InvalidWindowFunctionWindowingService extends WindowingService {
  @override
  List<double> get windowFunction => List<double>.filled(windowLength - 1, 1.0);
}
