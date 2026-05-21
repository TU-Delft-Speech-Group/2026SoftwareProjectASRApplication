// AI-generated test coverage, reviewed before being added.

import 'dart:typed_data';

import 'package:asr_application/services/ctc/espnet_ctc_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/fakes/services/ctc/fake_ctc_backend.dart';

void main() {
  group('EspnetCtcService', () {
    test('runs ESPnet CTC input and returns token probabilities', () async {
      final ctcTensor = FakeCtcTensor(
        Float32List.fromList([0.1, 0.2, 0.7, 0.3, 0.4, 0.3]),
        [1, 2, 3],
      );
      final backend = FakeCtcBackend(outputs: {'ctc_out': ctcTensor});
      final service = EspnetCtcService(
        config: const EspnetCtcConfig(modelAssetPath: 'assets/models/ctc.onnx'),
        backend: backend,
      );

      await service.initialize();
      final output = await service.computeTokenProbabilities(
        EncoderOutput(
          values: Float32List.fromList([1, 2, 3, 4]),
          shape: const [1, 2, 2],
          encodedFrameCount: 2,
        ),
      );

      expect(backend.createdAssetPath, 'assets/models/ctc.onnx');
      expect(backend.session.inputs.keys.toList(), ['encoder_out']);
      expect(backend.session.inputs['encoder_out']!.shape, [1, 2, 2]);
      expect(await backend.session.inputs['encoder_out']!.asList(), [
        1.0,
        2.0,
        3.0,
        4.0,
      ]);
      expect(output.shape, [1, 2, 3]);
      expect(output.values[0], closeTo(0.1, 0.000001));
      expect(output.values[1], closeTo(0.2, 0.000001));
      expect(output.values[2], closeTo(0.7, 0.000001));
      expect(output.values[3], closeTo(0.3, 0.000001));
      expect(output.values[4], closeTo(0.4, 0.000001));
      expect(output.values[5], closeTo(0.3, 0.000001));
      expect(backend.createdTensors.single.disposeCalled, isTrue);
      expect(ctcTensor.disposeCalled, isTrue);

      await service.dispose();
      expect(service.isInitialized, isFalse);
      expect(backend.session.closed, isTrue);
    });

    test('initializes only once', () async {
      final backend = FakeCtcBackend(outputs: const {});
      final service = EspnetCtcService(
        config: const EspnetCtcConfig(modelAssetPath: 'assets/models/ctc.onnx'),
        backend: backend,
      );

      await service.initialize();
      await service.initialize();

      expect(backend.createSessionCallCount, 1);
    });

    test('requires initialization before computing probabilities', () async {
      final service = EspnetCtcService(
        config: const EspnetCtcConfig(modelAssetPath: 'assets/models/ctc.onnx'),
        backend: FakeCtcBackend(outputs: const {}),
      );

      await expectLater(
        service.computeTokenProbabilities(
          EncoderOutput(
            values: Float32List.fromList([1]),
            shape: const [1, 1, 1],
          ),
        ),
        throwsStateError,
      );
    });

    test('requires the ESPnet CTC output name', () async {
      final unexpectedOutput = FakeCtcTensor(Float32List.fromList([1, 2]), [
        1,
        1,
        2,
      ]);
      final backend = FakeCtcBackend(
        outputs: {'unexpected_ctc': unexpectedOutput},
      );
      final service = EspnetCtcService(
        config: const EspnetCtcConfig(modelAssetPath: 'assets/models/ctc.onnx'),
        backend: backend,
      );

      await service.initialize();

      await expectLater(
        service.computeTokenProbabilities(
          EncoderOutput(
            values: Float32List.fromList([1, 2]),
            shape: const [1, 1, 2],
          ),
        ),
        throwsStateError,
      );
      expect(backend.createdTensors.single.disposeCalled, isTrue);
      expect(unexpectedOutput.disposeCalled, isTrue);
    });

    test('disposes input tensor when inference fails', () async {
      final backend = FakeCtcBackend(
        outputs: const {},
        runError: StateError('inference failed'),
      );
      final service = EspnetCtcService(
        config: const EspnetCtcConfig(modelAssetPath: 'assets/models/ctc.onnx'),
        backend: backend,
      );

      await service.initialize();

      await expectLater(
        service.computeTokenProbabilities(
          EncoderOutput(
            values: Float32List.fromList([1, 2]),
            shape: const [1, 1, 2],
          ),
        ),
        throwsStateError,
      );
      expect(backend.createdTensors.single.disposeCalled, isTrue);
    });
  });
}
