import 'dart:io';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:path/path.dart' as p;

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/exceptions/model/model_not_found_exception.dart';
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
        Result<ModelList> result = await repository.getModelList();
        expect(result, isA<Ok>());
        expect(result.asOk.value.modelNames, isEmpty);

        mockModelNames = ['model1', 'model2'];

        await repository.retrieveModels();
        result = await repository.getModelList();
        expect(result, isA<Ok>());

        final modelList = result.asOk.value;
        expect(modelList.modelNames, ['model1', 'model2']);
      });

      test('does not keep models that are no longer available', () async {
        mockModelNames = ['model1', 'old_model'];
        await repository.retrieveModels();
        Result<ModelList> result = await repository.getModelList();
        expect(result, isA<Ok>());
        expect(result.asOk.value.modelNames, mockModelNames);

        mockModelNames = ['model1', 'model2'];
        await repository.retrieveModels();
        result = await repository.getModelList();
        expect(result, isA<Ok>());

        final modelList = result.asOk.value;
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
        final result = await repository.getModelList();

        expect(result, isA<Ok>());
        expect(result.asOk.value.modelNames, []);
      });

      test('returns the list of available models', () async {
        mockModelNames = ['model1', 'model2'];
        expect(await repository.retrieveModels(), isA<Ok>());

        final result = await repository.getModelList();

        expect(result, isA<Ok>());
        expect(result.asOk.value.modelNames, ['model1', 'model2']);
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
    });
  });
}
