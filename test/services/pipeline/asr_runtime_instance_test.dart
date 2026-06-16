import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:asr_application/services/engines/espnet/pipeline/espnet_asr_runtime.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/fakes/services/audio/fake_vad_service.dart';
import '../../../testing/fakes/services/pipeline/fake_asr_runtime.dart';

AsrRuntime _runtime({FakeVadService? vad}) => EspnetAsrRuntime(
  pipeline: fakeAsrPipeline(),
  transcriptionService: StreamingTranscriptionService(
    encode: (_) async => (const <double>[], const <int>[0, 2], null),
    decoder: const DecoderService(),
    textService: const StubTokenIdToTextService(),
  ),
  vadService: vad,
);

void main() {
  group('EspnetAsrRuntime', () {
    group('dispose', () {
      test('completes without error when vadService is null', () async {
        final runtime = _runtime();
        await expectLater(runtime.dispose(), completes);
      });

      test('calls dispose on vadService when present', () async {
        final vad = FakeVadService();
        final runtime = _runtime(vad: vad);

        await runtime.dispose();

        expect(vad.disposeCalls, equals(1));
      });

      test('disposes vadService even if pipeline dispose throws', () async {
        final vad = FakeVadService();
        final runtime = EspnetAsrRuntime(
          pipeline: throwingAsrPipeline(),
          transcriptionService: StreamingTranscriptionService(
            encode: (_) async => (const <double>[], const <int>[0, 2], null),
            decoder: const DecoderService(),
            textService: const StubTokenIdToTextService(),
          ),
          vadService: vad,
        );
        await runtime.pipeline.initialize();

        await expectLater(runtime.dispose(), throwsException);

        expect(vad.disposeCalls, equals(1));
      });

      test('vadService is null when not provided', () {
        final runtime = _runtime();
        expect(runtime.vadService, isNull);
      });

      test('vadService is set when provided', () {
        final vad = FakeVadService();
        final runtime = _runtime(vad: vad);
        expect(runtime.vadService, same(vad));
      });
    });
  });
}
