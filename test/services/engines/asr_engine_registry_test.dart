// This file is AI-generated. It has been fully reviewed by a human before pushing. 

import 'dart:io';
import 'dart:typed_data';

import 'package:asr_application/domain/models/model/model.dart';
import 'package:asr_application/domain/models/model/model_files.dart';
import 'package:asr_application/domain/models/model/model_type.dart';
import 'package:asr_application/services/audio/vad_service.dart';
import 'package:asr_application/services/engines/asr_engine.dart';
import 'package:asr_application/services/engines/asr_engine_registry.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsrEngineRegistry', () {
    test(
      'delegates runtime creation to the engine matching model type',
      () async {
        final runtime = _FakeRuntime();
        final engine = _FakeEngine(
          modelType: ModelType.espnet,
          runtime: runtime,
        );
        final registry = AsrEngineRegistry(engines: [engine]);
        final model = _model(modelType: ModelType.espnet);

        final result = await registry.createRuntime(model);

        expect(result, same(runtime));
        expect(engine.seenModel, same(model));
      },
    );

    test('reports whether a model type is supported', () {
      final registry = AsrEngineRegistry(
        engines: [_FakeEngine(modelType: ModelType.espnet)],
      );

      expect(registry.supports(ModelType.espnet), isTrue);
      expect(registry.supports('unknown'), isFalse);
    });

    test('throws when no engine is registered for the model type', () async {
      final registry = AsrEngineRegistry(
        engines: [_FakeEngine(modelType: ModelType.espnet)],
      );

      expect(
        () => registry.createRuntime(_model(modelType: 'unknown')),
        throwsUnsupportedError,
      );
    });

    test('throws when two engines register the same model type', () {
      expect(
        () => AsrEngineRegistry(
          engines: [
            _FakeEngine(modelType: ModelType.espnet),
            _FakeEngine(modelType: ModelType.espnet),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}

Model _model({required String modelType}) {
  return Model(
    name: 'test-model',
    modelType: modelType,
    files: ModelFiles(
      ctcPath: File('ctc.onnx'),
      encoderPath: File('encoder.onnx'),
      vocabPath: File('vocab.txt'),
    ),
  );
}

final class _FakeEngine implements AsrEngine {
  _FakeEngine({required this.modelType, AsrRuntime? runtime})
    : runtime = runtime ?? _FakeRuntime();

  @override
  final String modelType;

  final AsrRuntime runtime;
  Model? seenModel;

  @override
  Future<AsrRuntime> createRuntime(Model model) async {
    seenModel = model;
    return runtime;
  }
}

final class _FakeRuntime implements AsrRuntime {
  @override
  final AsrTranscriptionService transcriptionService =
      _FakeTranscriptionService();

  @override
  VadService? get vadService => null;

  @override
  Future<void> dispose() async {}
}

final class _FakeTranscriptionService implements AsrTranscriptionService {
  @override
  String get confirmedText => '';

  @override
  void commit() {}

  @override
  Future<StreamResult?> process(List<Float32List> allFrames) async => null;

  @override
  void reset() {}

  @override
  void skipTo(int frameCount) {}
}
