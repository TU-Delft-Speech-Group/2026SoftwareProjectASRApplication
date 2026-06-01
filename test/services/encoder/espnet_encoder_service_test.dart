import 'dart:typed_data';

import 'package:asr_application/services/encoder/espnet_encoder_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/fakes/services/encoder/fake_encoder_backend.dart';

void main() {
  group('EspnetEncoderService', () {
    test('runs ESPnet encoder inputs and returns configured output', () async {
      final backend = FakeEncoderBackend(
        outputs: {
          'encoder_out': FakeEncoderTensor(
            Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
            [1, 2, 2],
          ),
          'encoder_out_lens': FakeEncoderTensor(Int64List.fromList([2]), [1]),
        },
      );
      final service = EspnetEncoderService(
        config: EspnetEncoderConfig(
          modelAssetPath: 'assets/models/encoder.onnx',
        ),
        backend: backend,
      );

      await service.initialize();
      final output = await service.encode(
        EncoderFrameBuffer.fromFrames([
          Float32List.fromList([1, 2, 3]),
          Float32List.fromList([4, 5, 6]),
        ]),
      );

      expect(backend.createdAssetPath, 'assets/models/encoder.onnx');
      expect(backend.session.inputs.keys.toList(), ['feats']);
      expect(backend.session.inputs['feats']!.shape, [1, 2, 3]);
      expect(output.shape, [1, 2, 2]);
      expect(output.values[0], closeTo(0.1, 0.000001));
      expect(output.values[1], closeTo(0.2, 0.000001));
      expect(output.values[2], closeTo(0.3, 0.000001));
      expect(output.values[3], closeTo(0.4, 0.000001));
      expect(output.encodedFrameCount, 2);

      await service.dispose();
      expect(backend.session.closed, isTrue);
    });

    test('requires initialization before encoding', () async {
      final service = EspnetEncoderService(
        config: EspnetEncoderConfig(
          modelAssetPath: 'assets/models/encoder.onnx',
        ),
        backend: FakeEncoderBackend(outputs: const {}),
      );

      await expectLater(
        service.encode(
          EncoderFrameBuffer.fromFrames([
            Float32List.fromList([1]),
          ]),
        ),
        throwsStateError,
      );
    });

    test('requires the ESPnet encoder output name', () async {
      final backend = FakeEncoderBackend(
        outputs: {
          'unexpected_encoder': FakeEncoderTensor(
            Float32List.fromList([1, 2]),
            [1, 1, 2],
          ),
        },
      );
      final service = EspnetEncoderService(
        config: EspnetEncoderConfig(
          modelAssetPath: 'assets/models/encoder.onnx',
        ),
        backend: backend,
      );

      await service.initialize();

      await expectLater(
        service.encode(
          EncoderFrameBuffer.fromFrames([
            Float32List.fromList([1, 2]),
          ]),
        ),
        throwsStateError,
      );
    });
  });
}
