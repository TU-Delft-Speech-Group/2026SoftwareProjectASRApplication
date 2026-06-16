import 'dart:typed_data';

import 'package:asr_application/services/audio/vad_service.dart';
import 'package:asr_application/services/engines/espnet/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:asr_application/services/engines/espnet/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/engines/espnet/pipeline/espnet_asr_pipeline.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../engines/espnet/ctc/fake_ctc_backend.dart';
import '../engines/espnet/encoder/fake_encoder_backend.dart';

class FakeAsrRuntime implements AsrRuntime {
  FakeAsrRuntime()
    : transcriptionService = StreamingTranscriptionService(
        encode: (_) async => (const <double>[], const <int>[0, 2], null),
        decoder: const DecoderService(),
        textService: const StubTokenIdToTextService(),
      );

  @override
  final AsrTranscriptionService transcriptionService;

  @override
  VadService? get vadService => null;

  int disposeCallCount = 0;

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }
}

EspnetAsrPipeline throwingAsrPipeline() {
  final encoder = EspnetEncoderService(
    config: EspnetEncoderConfig(modelAssetPath: 'assets/models/encoder.onnx'),
    backend: _ThrowingEncoderBackend(
      outputs: {
        'encoder_out': FakeEncoderTensor(Float32List.fromList([0.0]), [
          1,
          1,
          1,
        ]),
      },
    ),
  );
  final ctc = EspnetCtcService(
    config: EspnetCtcConfig(modelAssetPath: 'assets/models/ctc.onnx'),
    backend: FakeCtcBackend(
      outputs: {
        'ctc_out': FakeCtcTensor(Float32List.fromList([0.0, 0.0]), [1, 1, 2]),
      },
    ),
  );
  return EspnetAsrPipeline(encoder: encoder, ctc: ctc);
}

class _ThrowingEncoderBackend extends FakeEncoderBackend {
  _ThrowingEncoderBackend({required super.outputs});

  final _throwingSession = _ThrowingEncoderSession();

  @override
  Future<FakeEncoderSession> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  }) async {
    createdAssetPath = assetPath;
    _throwingSession.outputs = outputs;
    return _throwingSession;
  }
}

class _ThrowingEncoderSession extends FakeEncoderSession {
  @override
  Future<void> close() async {
    throw Exception('pipeline dispose failed');
  }
}

EspnetAsrPipeline fakeAsrPipeline() {
  final encoder = EspnetEncoderService(
    config: EspnetEncoderConfig(modelAssetPath: 'assets/models/encoder.onnx'),
    backend: FakeEncoderBackend(
      outputs: {
        'encoder_out': FakeEncoderTensor(Float32List.fromList([0.0]), [
          1,
          1,
          1,
        ]),
      },
    ),
  );
  final ctc = EspnetCtcService(
    config: EspnetCtcConfig(modelAssetPath: 'assets/models/ctc.onnx'),
    backend: FakeCtcBackend(
      outputs: {
        'ctc_out': FakeCtcTensor(Float32List.fromList([0.0, 0.0]), [1, 1, 2]),
      },
    ),
  );
  return EspnetAsrPipeline(encoder: encoder, ctc: ctc);
}
