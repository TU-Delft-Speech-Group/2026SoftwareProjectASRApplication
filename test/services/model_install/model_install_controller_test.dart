import 'dart:collection';

import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/data/services/remote/remote_model_service.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<ModelPackageService>(),
  MockSpec<RemoteModelService>(),
  MockSpec<ModelRepository>(),
])
import 'model_install_controller_test.mocks.dart';

void main() {
  late MockModelPackageService packageService;
  late MockRemoteModelService remoteService;
  late MockModelRepository modelRepo;

  ModelList listOf(List<String> names) =>
      ModelList(modelNames: UnmodifiableListView(names));

  setUp(() {
    packageService = MockModelPackageService();
    remoteService = MockRemoteModelService();
    modelRepo = MockModelRepository();
    provideDummy<Result<void>>(Result.ok(null));
    provideDummy<Result<ModelList>>(Result.ok(listOf(const [])));
  });

  ModelInstallController buildController({required String initialModelName}) {
    return ModelInstallController(
      packageService: packageService,
      remoteService: remoteService,
      modelRepo: modelRepo,
      initialModelName: initialModelName,
    );
  }

  group('deleteModel', () {
    test('removes a non-active model without changing activeModelName', () async {
      final controller = buildController(initialModelName: 'model-a');
      when(
        modelRepo.deleteModel('model-b'),
      ).thenAnswer((_) async => Result.ok(null));

      final result = await controller.deleteModel('model-b');

      expect(result, isA<Ok>());
      expect(controller.activeModelName, 'model-a');
      verify(modelRepo.deleteModel('model-b')).called(1);
      verifyNever(modelRepo.getModelList());
    });

    test('switches to another model when the active model is deleted', () async {
      final controller = buildController(initialModelName: 'model-a');
      when(
        modelRepo.deleteModel('model-a'),
      ).thenAnswer((_) async => Result.ok(null));
      when(
        modelRepo.getModelList(),
      ).thenAnswer((_) async => Result.ok(listOf(['model-b'])));

      final result = await controller.deleteModel('model-a');

      expect(result, isA<Ok>());
      expect(controller.activeModelName, 'model-b');
    });

    test('clears activeModelName when the last model is deleted', () async {
      final controller = buildController(initialModelName: 'model-a');
      when(
        modelRepo.deleteModel('model-a'),
      ).thenAnswer((_) async => Result.ok(null));
      when(
        modelRepo.getModelList(),
      ).thenAnswer((_) async => Result.ok(listOf(const [])));

      final result = await controller.deleteModel('model-a');

      expect(result, isA<Ok>());
      expect(controller.activeModelName, isNull);
    });

    test('notifies listeners on successful deletion', () async {
      final controller = buildController(initialModelName: 'model-a');
      when(
        modelRepo.deleteModel('model-a'),
      ).thenAnswer((_) async => Result.ok(null));
      when(
        modelRepo.getModelList(),
      ).thenAnswer((_) async => Result.ok(listOf(const [])));
      var notified = false;
      controller.addListener(() => notified = true);

      await controller.deleteModel('model-a');

      expect(notified, isTrue);
    });

    test('returns the repository error and leaves activeModelName unchanged '
        'when deletion fails', () async {
      final controller = buildController(initialModelName: 'model-a');
      final error = Exception('disk error');
      when(
        modelRepo.deleteModel('model-a'),
      ).thenAnswer((_) async => Result.error(error));

      final result = await controller.deleteModel('model-a');

      expect(result, isA<Error>());
      expect((result as Error).error, error);
      expect(controller.activeModelName, 'model-a');
      verifyNever(modelRepo.getModelList());
    });
  });
}
