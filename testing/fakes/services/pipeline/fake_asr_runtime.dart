import 'dart:typed_data';

import 'package:asr_application/services/ctc/espnet_ctc_service.dart';
import 'package:asr_application/services/decoder/decoder_service.dart';
import 'package:asr_application/services/encoder/espnet_encoder_service.dart';
import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';

import '../ctc/fake_ctc_backend.dart';
import '../encoder/fake_encoder_backend.dart';

class FakeAsrRuntime extends AsrRuntime {
  FakeAsrRuntime()
    : super(
        pipeline: fakeAsrPipeline(),
        streamingService: StreamingTranscriptionService(
          encode: (_) async => (const <double>[], const <int>[0, 2], null),
          decoder: const DecoderService(),
          textService: const StubTokenIdToTextService(),
        ),
      );

  int disposeCallCount = 0;

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }
}

AsrPipelineService fakeAsrPipeline() {
  final encoder = EspnetEncoderService(
    config: EspnetEncoderConfig(
      modelAssetPath: 'assets/models/encoder.onnx',
    ),
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
  return AsrPipelineService(encoder: encoder, ctc: ctc);
}
