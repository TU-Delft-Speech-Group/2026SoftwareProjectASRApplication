import 'package:asr_application/exceptions/pipeline/pipeline_stage_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PipelineStageException', () {
    test('exposes stage and cause', () {
      final cause = StateError('onnx failed');
      final exception = PipelineStageException(stage: 'encode', cause: cause);
      expect(exception.stage, equals('encode'));
      expect(exception.cause, same(cause));
    });

    test('stackTrace defaults to null', () {
      final exception = PipelineStageException(
        stage: 'decode',
        cause: Exception('test'),
      );
      expect(exception.stackTrace, isNull);
    });

    test('stackTrace is accessible when provided', () {
      final st = StackTrace.current;
      final exception = PipelineStageException(
        stage: 'tokenise',
        cause: Exception('test'),
        stackTrace: st,
      );
      expect(exception.stackTrace, same(st));
    });

    test('toString includes stage and cause', () {
      final exception = PipelineStageException(
        stage: 'encode',
        cause: StateError('session closed'),
      );
      expect(exception.toString(), contains('encode'));
      expect(exception.toString(), contains('session closed'));
    });

    test('is an Exception', () {
      final exception = PipelineStageException(
        stage: 'decode',
        cause: Exception('test'),
      );
      expect(exception, isA<Exception>());
    });
  });
}
