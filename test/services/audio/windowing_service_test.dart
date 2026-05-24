import 'package:asr_application/exceptions/audio/window_function_size_incompatible_exception.dart';
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
    test('emits no frame before the leading reflect is complete', () {
      final frames = service.addSamples(samples(service.windowLength ~/ 2));

      expect(frames, isEmpty);
    });

    test('emits one frame once the leading reflect can be built', () {
      final frames = service.addSamples(samples(service.windowLength ~/ 2 + 1));

      expect(frames, hasLength(1));
      expect(frames.single, isA<SampleWindow>());
    });

    test(
      'Adding 37037 (length of poisoned_potato_test.wav), should result in 232 frames',
      () {
        final frames = service.addSamples(
          List<double>.filled(37_037, 0),
          flush: true,
        );

        expect(frames, hasLength(232));
      },
    );

    test('emits three frames at the third hop boundary', () {
      final frames = service.addSamples(
        samples(service.windowLength ~/ 2 + 2 * service.hopLength + 1),
      );

      expect(frames, hasLength(3));
    });

    test('stop emits the trailing centered frames', () {
      final initialFrames = service.addSamples(
        samples(service.windowLength + 1),
      );
      final flushedFrames = service.stop();

      expect(initialFrames.length + flushedFrames.length, 3);
    });

    test('reset discards buffered samples', () {
      service.addSamples(samples(service.windowLength ~/ 2 - 1));

      service.reset();

      final frames = service.addSamples(samples(service.windowLength ~/ 2 - 1));
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
