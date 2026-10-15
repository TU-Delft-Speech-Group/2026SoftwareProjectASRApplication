import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WhisperMelMismatchException.tryParse', () {
    test('reads got/expected from the ONNX Runtime error', () {
      const error =
          'PlatformException(INFERENCE_ERROR, Got invalid dimensions for input: '
          'input_features for the following indices\n index: 1 Got: 80 Expected: 128\n'
          ' Please fix either the inputs/outputs or the model., null, null)';

      final parsed = WhisperMelMismatchException.tryParse(error);

      expect(parsed, isNotNull);
      expect(parsed!.got, 80);
      expect(parsed.expected, 128);
      expect(parsed.toString(), contains('needs 128 mel bins'));
    });

    test('ignores other dimension errors', () {
      const error =
          'Got invalid dimensions for input: input_features for the following '
          'indices\n index: 2 Got: 1500 Expected: 3000';
      expect(WhisperMelMismatchException.tryParse(error), isNull);
    });

    test('ignores unrelated errors', () {
      expect(
        WhisperMelMismatchException.tryParse('Invalid input name: input_ids'),
        isNull,
      );
    });
  });
}
