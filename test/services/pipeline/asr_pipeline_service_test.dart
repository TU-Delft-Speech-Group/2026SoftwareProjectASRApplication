import 'dart:typed_data';

import 'package:asr_application/services/engines/espnet/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/engines/espnet/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/engines/espnet/pipeline/espnet_asr_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/fakes/services/engines/espnet/ctc/fake_ctc_backend.dart';
import '../../../testing/fakes/services/engines/espnet/encoder/fake_encoder_backend.dart';

EspnetAsrPipeline _buildPipeline({
  required FakeEncoderBackend encoderBackend,
  required FakeCtcBackend ctcBackend,
}) {
  final encoder = EspnetEncoderService(
    config: EspnetEncoderConfig(modelAssetPath: 'assets/models/encoder.onnx'),
    backend: encoderBackend,
  );
  final ctc = EspnetCtcService(
    config: EspnetCtcConfig(modelAssetPath: 'assets/models/ctc.onnx'),
    backend: ctcBackend,
  );
  return EspnetAsrPipeline(encoder: encoder, ctc: ctc);
}

void main() {
  group('EspnetAsrPipeline', () {
    test('initialize wires up both encoder and CTC sessions', () async {
      final encoderBackend = FakeEncoderBackend(outputs: const {});
      final ctcBackend = FakeCtcBackend(outputs: const {});
      final pipeline = _buildPipeline(
        encoderBackend: encoderBackend,
        ctcBackend: ctcBackend,
      );

      expect(pipeline.isInitialized, isFalse);
      await pipeline.initialize();

      expect(pipeline.isInitialized, isTrue);
      expect(encoderBackend.createdAssetPath, 'assets/models/encoder.onnx');
      expect(ctcBackend.createdAssetPath, 'assets/models/ctc.onnx');
    });

    test('encode runs encoder then forwards encoder output into CTC', () async {
      final encoderBackend = FakeEncoderBackend(
        outputs: {
          'encoder_out': FakeEncoderTensor(
            Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
            [1, 2, 2],
          ),
          'encoder_out_lens': FakeEncoderTensor(Int64List.fromList([2]), [1]),
        },
      );
      final ctcBackend = FakeCtcBackend(
        outputs: {
          'ctc_out': FakeCtcTensor(
            Float32List.fromList([0.5, 0.4, 0.1, 0.2, 0.7, 0.1]),
            [1, 2, 3],
          ),
        },
      );
      final pipeline = _buildPipeline(
        encoderBackend: encoderBackend,
        ctcBackend: ctcBackend,
      );
      await pipeline.initialize();

      final (values, shape, _) = await pipeline.encode([
        Float32List.fromList([1.0, 2.0, 3.0]),
        Float32List.fromList([4.0, 5.0, 6.0]),
      ]);

      expect(encoderBackend.session.inputs.keys.toList(), ['feats']);
      expect(encoderBackend.session.inputs['feats']!.shape, [1, 2, 3]);
      expect(ctcBackend.session.inputs.keys.toList(), ['x']);
      expect(ctcBackend.session.inputs['x']!.shape, [1, 2, 2]);
      expect(
        await ctcBackend.session.inputs['x']!.asFloat32List(),
        Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
      );
      expect(shape, [1, 2, 3]);
      expect(values, Float32List.fromList([0.5, 0.4, 0.1, 0.2, 0.7, 0.1]));
    });

    test('applies utterance MVN before sending features to encoder', () async {
      final encoderBackend = FakeEncoderBackend(
        outputs: {
          'encoder_out': FakeEncoderTensor(Float32List.fromList([0.0, 0.0]), [
            1,
            1,
            2,
          ]),
          'encoder_out_lens': FakeEncoderTensor(Int64List.fromList([1]), [1]),
        },
      );
      final ctcBackend = FakeCtcBackend(
        outputs: {
          'ctc_out': FakeCtcTensor(Float32List.fromList([0.0, 0.0, 0.0]), [
            1,
            1,
            3,
          ]),
        },
      );
      final pipeline = _buildPipeline(
        encoderBackend: encoderBackend,
        ctcBackend: ctcBackend,
      );
      await pipeline.initialize();

      await pipeline.encode([
        Float32List.fromList([1.0, 2.0]),
        Float32List.fromList([3.0, 4.0]),
      ]);

      final feats = await encoderBackend.session.inputs['feats']!
          .asFloat32List();
      // means per dim: [(1+3)/2, (2+4)/2] = [2.0, 3.0]
      // normalized:    [-1, -1, 1, 1]
      expect(feats[0], closeTo(-1.0, 1e-6));
      expect(feats[1], closeTo(-1.0, 1e-6));
      expect(feats[2], closeTo(1.0, 1e-6));
      expect(feats[3], closeTo(1.0, 1e-6));
    });

    test('truncates to the last maxFrames when input exceeds the cap', () async {
      final encoderBackend = FakeEncoderBackend(
        outputs: {
          'encoder_out': FakeEncoderTensor(Float32List.fromList([0.0, 0.0]), [
            1,
            1,
            2,
          ]),
          'encoder_out_lens': FakeEncoderTensor(Int64List.fromList([1]), [1]),
        },
      );
      final ctcBackend = FakeCtcBackend(
        outputs: {
          'ctc_out': FakeCtcTensor(Float32List.fromList([0.0, 0.0, 0.0]), [
            1,
            1,
            3,
          ]),
        },
      );
      final encoder = EspnetEncoderService(
        config: EspnetEncoderConfig(
          modelAssetPath: 'assets/models/encoder.onnx',
        ),
        backend: encoderBackend,
      );
      final ctc = EspnetCtcService(
        config: EspnetCtcConfig(modelAssetPath: 'assets/models/ctc.onnx'),
        backend: ctcBackend,
      );
      final pipeline = EspnetAsrPipeline(
        encoder: encoder,
        ctc: ctc,
        maxFrames: 2,
      );
      await pipeline.initialize();

      await pipeline.encode([
        Float32List.fromList([1.0]),
        Float32List.fromList([2.0]),
        Float32List.fromList([3.0]),
        Float32List.fromList([4.0]),
      ]);

      // Only the last two frames should reach the encoder; their MVN-normalized
      // values are [-0.5, 0.5] (mean 3.5).
      expect(encoderBackend.session.inputs['feats']!.shape, [1, 2, 1]);
      final feats = await encoderBackend.session.inputs['feats']!
          .asFloat32List();
      expect(feats[0], closeTo(-0.5, 1e-6));
      expect(feats[1], closeTo(0.5, 1e-6));
    });

    test('throws ArgumentError when called with an empty frame list', () async {
      final encoderBackend = FakeEncoderBackend(outputs: const {});
      final ctcBackend = FakeCtcBackend(outputs: const {});
      final pipeline = _buildPipeline(
        encoderBackend: encoderBackend,
        ctcBackend: ctcBackend,
      );
      await pipeline.initialize();

      await expectLater(pipeline.encode([]), throwsArgumentError);
    });

    test('throws ArgumentError when encoder returns a non-3D shape', () async {
      final encoderBackend = FakeEncoderBackend(
        outputs: {
          'encoder_out': FakeEncoderTensor(Float32List.fromList([0.1, 0.2]), [
            1,
            2,
          ]),
          'encoder_out_lens': FakeEncoderTensor(Int64List.fromList([1]), [1]),
        },
      );
      final ctcBackend = FakeCtcBackend(outputs: const {});
      final pipeline = _buildPipeline(
        encoderBackend: encoderBackend,
        ctcBackend: ctcBackend,
      );
      await pipeline.initialize();

      await expectLater(
        pipeline.encode([
          Float32List.fromList([1.0, 2.0]),
        ]),
        throwsArgumentError,
      );
    });

    test(
      'throws ArgumentError when encoder returns mismatched values length',
      () async {
        final encoderBackend = FakeEncoderBackend(
          outputs: {
            'encoder_out': FakeEncoderTensor(
              Float32List.fromList([0.1, 0.2, 0.3]),
              [1, 2, 4],
            ),
            'encoder_out_lens': FakeEncoderTensor(Int64List.fromList([1]), [1]),
          },
        );
        final ctcBackend = FakeCtcBackend(outputs: const {});
        final pipeline = _buildPipeline(
          encoderBackend: encoderBackend,
          ctcBackend: ctcBackend,
        );
        await pipeline.initialize();

        await expectLater(
          pipeline.encode([
            Float32List.fromList([1.0, 2.0]),
          ]),
          throwsArgumentError,
        );
      },
    );

    test(
      'throws ArgumentError when CTC returns an unsupported shape',
      () async {
        final encoderBackend = FakeEncoderBackend(
          outputs: {
            'encoder_out': FakeEncoderTensor(
              Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
              [1, 2, 2],
            ),
            'encoder_out_lens': FakeEncoderTensor(Int64List.fromList([2]), [1]),
          },
        );
        final ctcBackend = FakeCtcBackend(
          outputs: {
            'ctc_out': FakeCtcTensor(Float32List.fromList([0.5, 0.5]), [
              2,
              3,
              4,
            ]),
          },
        );
        final pipeline = _buildPipeline(
          encoderBackend: encoderBackend,
          ctcBackend: ctcBackend,
        );
        await pipeline.initialize();

        await expectLater(
          pipeline.encode([
            Float32List.fromList([1.0, 2.0]),
          ]),
          throwsArgumentError,
        );
      },
    );

    test(
      'throws ArgumentError when CTC returns mismatched values length',
      () async {
        final encoderBackend = FakeEncoderBackend(
          outputs: {
            'encoder_out': FakeEncoderTensor(
              Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
              [1, 2, 2],
            ),
            'encoder_out_lens': FakeEncoderTensor(Int64List.fromList([2]), [1]),
          },
        );
        final ctcBackend = FakeCtcBackend(
          outputs: {
            'ctc_out': FakeCtcTensor(Float32List.fromList([0.5, 0.4]), [
              1,
              2,
              3,
            ]),
          },
        );
        final pipeline = _buildPipeline(
          encoderBackend: encoderBackend,
          ctcBackend: ctcBackend,
        );
        await pipeline.initialize();

        await expectLater(
          pipeline.encode([
            Float32List.fromList([1.0, 2.0]),
          ]),
          throwsArgumentError,
        );
      },
    );

    test('dispose tears down both child services', () async {
      final encoderBackend = FakeEncoderBackend(outputs: const {});
      final ctcBackend = FakeCtcBackend(outputs: const {});
      final pipeline = _buildPipeline(
        encoderBackend: encoderBackend,
        ctcBackend: ctcBackend,
      );
      await pipeline.initialize();

      await pipeline.dispose();

      expect(encoderBackend.session.closed, isTrue);
      expect(ctcBackend.session.closed, isTrue);
      expect(pipeline.isInitialized, isFalse);
    });
  });
}
