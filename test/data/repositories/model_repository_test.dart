import 'dart:io';
import 'package:asr_application/domain/models/model/model_type.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:path/path.dart' as p;

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/exceptions/model/model_not_found_exception.dart';
import 'package:asr_application/exceptions/model/model_storage_exception.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../testing/utils/paramaterize.dart';
@GenerateNiceMocks([MockSpec<LocalModelService>()])
import 'model_repository_test.mocks.dart';

import '../../../testing/utils/result.dart';

void main() {
  group('LocalModelRepository', () {
    late MockLocalModelService mockLocalModelService;
    late LocalModelStorageConfig config;
    late ModelRepository repository;

    List<String> mockModelNames = [];
    String modelDirectoryPath = 'models';
    Directory modelDirectory = Directory(modelDirectoryPath);

    setUp(() {
      mockLocalModelService = MockLocalModelService();
      config = LocalModelStorageConfig();

      mockModelNames = [];

      when(
        mockLocalModelService.getAvailableModels(),
      ).thenAnswer((_) async => mockModelNames);
      when(
        mockLocalModelService.getModelDirectory(any),
      ).thenAnswer((_) async => modelDirectory);

      repository = ModelRepository(
        localModelService: mockLocalModelService,
        config: config,
      );
    });

    group('retrieveModels', () {
      test('calls the local model service to fetch available models', () async {
        await repository.retrieveModels();

        verify(mockLocalModelService.getAvailableModels()).called(1);
      });

      test('refreshes the list of available models', () async {
        mockModelNames = [];
        ModelList result = repository.getModelList();
        expect(result, isA<ModelList>());
        expect(result.modelNames, isEmpty);

        mockModelNames = ['model1', 'model2'];

        await repository.retrieveModels();
        result = repository.getModelList();
        expect(result, isA<ModelList>());

        final modelList = result;
        expect(modelList.modelNames, ['model1', 'model2']);
      });

      test('does not keep models that are no longer available', () async {
        mockModelNames = ['model1', 'old_model'];
        await repository.retrieveModels();
        ModelList result = repository.getModelList();
        expect(result, isA<ModelList>());
        expect(result.modelNames, mockModelNames);

        mockModelNames = ['model1', 'model2'];
        await repository.retrieveModels();
        result = repository.getModelList();
        expect(result, isA<ModelList>());

        final modelList = result;
        expect(modelList.modelNames, ['model1', 'model2']);
      });

      test('returns error if fetching available models fails', () async {
        when(
          mockLocalModelService.getAvailableModels(),
        ).thenThrow(Exception(""));

        final result = await repository.retrieveModels();

        expect(result, isA<Error>());
      });
    });

    group('getModelList', () {
      test('returns empty list if no models have been retrieved', () async {
        final result = repository.getModelList();

        expect(result, isA<ModelList>());
        expect(result.modelNames, []);
      });

      test('returns the list of available models', () async {
        mockModelNames = ['model1', 'model2'];
        expect(await repository.retrieveModels(), isA<Ok>());

        final result = repository.getModelList();

        expect(result, isA<ModelList>());
        expect(result.modelNames, ['model1', 'model2']);
      });
    });

    group('getModel', () {
      setUp(() async {
        mockModelNames = ['model1', 'model2'];
        await repository.retrieveModels();
      });

      test('returns ModelNotFoundException if model is not found', () async {
        final result = await repository.getModel('non_existent_model');

        expect(result, isA<Error>());
        expect(result.asError.error, isA<ModelNotFoundException>());
      });

      each('for all available models:', ['model1', 'model2'])((modelName) {
        test('returns Model for $modelName', () async {
          final result = await repository.getModel(modelName);
          expect(result, isA<Ok>());

          final model = result.asOk.value;
          expect(model.name, modelName);
        });

        test('returns correct file paths for $modelName', () async {
          final result = await repository.getModel(modelName);
          expect(result, isA<Ok>());

          final model = result.asOk.value;
          expect(
            model.files.ctcPath.path,
            p.join(modelDirectory.path, config.ctcFilePath),
          );
          expect(
            model.files.encoderPath.path,
            p.join(modelDirectory.path, config.encoderFilePath),
          );
          // decoderPath is null because the test directory does not exist on
          // disk — models without a decoder file are valid (CTC-only).
          expect(model.files.decoderPath, isNull);
          expect(
            model.files.vocabPath.path,
            p.join(modelDirectory.path, config.vocabFilePath),
          );
        });
      });

      test('metadata is null when no manifest is present on disk', () async {
        final result = await repository.getModel('model1');
        expect(result, isA<Ok>());
        expect(result.asOk.value.metadata, isNull);
      });

      test(
        'model type defaults to espnet when no manifest is present',
        () async {
          final result = await repository.getModel('model1');
          expect(result, isA<Ok>());
          expect(result.asOk.value.modelType, ModelType.espnet);
        },
      );
    });

    group('getModel — manifest metadata', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('repo_meta_');
        when(
          mockLocalModelService.getModelDirectory(any),
        ).thenAnswer((_) async => tempDir);
        mockModelNames = ['model1'];
        await repository.retrieveModels();
      });

      tearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      test('parses the vocab block from a preserved manifest', () async {
        await File(p.join(tempDir.path, config.manifestFilePath)).writeAsString(
          '{"format_version":"2","model_name":"model1","has_decoder":true,'
          '"vocab":{"blank_id":0,"unk_id":1,"sos_eos_id":4999,'
          '"suppressed_ids":[0,2,3,4],"word_boundary_marker":"▁"},"files":{}}',
        );

        final model = (await repository.getModel('model1')).asOk.value;

        expect(model.metadata, isNotNull);
        expect(model.metadata!.blankId, 0);
        expect(model.metadata!.sosEosId, 4999);
        expect(model.metadata!.suppressedIds, {0, 2, 3, 4});
        expect(model.metadata!.wordBoundaryMarker, '▁');
      });

      test(
        'blank id is always suppressed even if omitted from the list',
        () async {
          await File(
            p.join(tempDir.path, config.manifestFilePath),
          ).writeAsString(
            '{"format_version":"2","model_name":"model1","has_decoder":false,'
            '"vocab":{"blank_id":0,"unk_id":1,"sos_eos_id":4999,'
            '"suppressed_ids":[2,3],"word_boundary_marker":null},"files":{}}',
          );

          final model = (await repository.getModel('model1')).asOk.value;

          expect(model.metadata!.suppressedIds, {0, 2, 3});
        },
      );

      test(
        'metadata is null for a version 1 manifest (no vocab block)',
        () async {
          await File(
            p.join(tempDir.path, config.manifestFilePath),
          ).writeAsString(
            '{"format_version":"1","model_name":"model1","has_decoder":false,'
            '"files":{}}',
          );

          final model = (await repository.getModel('model1')).asOk.value;

          expect(model.metadata, isNull);
        },
      );

      test('reads model_type from a preserved manifest', () async {
        await File(p.join(tempDir.path, config.manifestFilePath)).writeAsString(
          '{"format_version":"2","model_name":"model1",'
          '"model_type":"custom-engine","has_decoder":false,"files":{}}',
        );

        final model = (await repository.getModel('model1')).asOk.value;

        expect(model.modelType, 'custom-engine');
      });
    });

    group('renameModel', () {
      setUp(() async {
        mockModelNames = ['model1', 'model2'];
        await repository.retrieveModels();
      });

      test('renames the model in local storage', () async {
        final result = await repository.renameModel('model1', 'renamed');

        expect(result, isA<Ok>());
        verify(
          mockLocalModelService.renameModel('model1', 'renamed'),
        ).called(1);
      });

      test('updates the cached model list', () async {
        await repository.renameModel('model1', 'renamed');

        final result = repository.getModelList();

        expect(result.modelNames, ['renamed', 'model2']);
      });

      test('returns not found when the source model is missing', () async {
        final result = await repository.renameModel('missing', 'renamed');

        expect(result, isA<Error>());
        expect(result.asError.error, isA<ModelNotFoundException>());
        verifyNever(mockLocalModelService.renameModel('missing', 'renamed'));
      });

      test('returns storage error when the new name already exists', () async {
        final result = await repository.renameModel('model1', 'model2');

        expect(result, isA<Error>());
        expect(result.asError.error, isA<ModelStorageException>());
        verifyNever(mockLocalModelService.renameModel('model1', 'model2'));
      });
    });
  });
}
