import 'dart:collection';

import 'package:asr_application/data/repositories/model_repository.dart';
import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/data/services/remote/remote_model_service.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/exceptions/model/invalid_model_file_exception.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<ModelPackageService>(),
  MockSpec<RemoteModelService>(),
  MockSpec<ModelRepository>(),
  MockSpec<SettingsRepository>(),
])
import 'model_install_controller_test.mocks.dart';

void main() {
  late MockModelPackageService packageService;
  late MockRemoteModelService remoteService;
  late MockModelRepository modelRepo;
  late MockSettingsRepository mockSettingsRepository;

  ModelList listOf(List<String> names) =>
      ModelList(modelNames: UnmodifiableListView(names));

  setUp(() {
    packageService = MockModelPackageService();
    remoteService = MockRemoteModelService();
    modelRepo = MockModelRepository();
    mockSettingsRepository = MockSettingsRepository();
    provideDummy<Result<void>>(Result.ok(null));
    provideDummy<Result<ModelList>>(Result.ok(listOf(const [])));
  });

  ModelInstallController buildController({required String initialModelName}) {
    String? activeModelName = initialModelName;
    when(
      mockSettingsRepository.getModelName(),
    ).thenAnswer((_) => activeModelName);
    when(mockSettingsRepository.setModelName(any)).thenAnswer((invocation) {
      activeModelName = invocation.positionalArguments.single as String?;
      return Future.value();
    });

    return ModelInstallController(
      packageService: packageService,
      remoteService: remoteService,
      modelRepo: modelRepo,
      settingsRepository: mockSettingsRepository,
    );
  }

  ModelInstallController controllerWithPick(String? path) {
    return ModelInstallController(
      packageService: packageService,
      remoteService: remoteService,
      modelRepo: modelRepo,
      filePicker: () async => path,
      settingsRepository: mockSettingsRepository,
    );
  }

  group('deleteModel', () {
    test(
      'removes a non-active model without changing activeModelName',
      () async {
        final controller = buildController(initialModelName: 'model-a');
        when(
          modelRepo.deleteModel('model-b'),
        ).thenAnswer((_) async => Result.ok(null));

        final result = await controller.deleteModel('model-b');

        expect(result, isA<Ok>());
        expect(controller.activeModelName, 'model-a');
        verify(modelRepo.deleteModel('model-b')).called(1);
        verifyNever(modelRepo.getModelList());
      },
    );

    test(
      'switches to another model when the active model is deleted',
      () async {
        final controller = buildController(initialModelName: 'model-a');
        when(
          modelRepo.deleteModel('model-a'),
        ).thenAnswer((_) async => Result.ok(null));
        when(modelRepo.getModelList()).thenAnswer((_) => listOf(['model-b']));

        final result = await controller.deleteModel('model-a');

        expect(result, isA<Ok>());
        expect(controller.activeModelName, 'model-b');
      },
    );

    test('clears activeModelName when the last model is deleted', () async {
      final controller = buildController(initialModelName: 'model-a');
      when(
        modelRepo.deleteModel('model-a'),
      ).thenAnswer((_) async => Result.ok(null));
      when(modelRepo.getModelList()).thenAnswer((_) => listOf(const []));

      final result = await controller.deleteModel('model-a');

      expect(result, isA<Ok>());
      expect(controller.activeModelName, isNull);
    });

    test('notifies listeners on successful deletion', () async {
      final controller = buildController(initialModelName: 'model-a');
      when(
        modelRepo.deleteModel('model-a'),
      ).thenAnswer((_) async => Result.ok(null));
      when(modelRepo.getModelList()).thenAnswer((_) => listOf(const []));
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

  group('pickAndInstall file type validation', () {
    test(
      'returns InvalidModelFileException for a non-.asrmodel file',
      () async {
        final controller = controllerWithPick('/tmp/photo.jpg');

        final result = await controller.pickAndInstall();

        expect(result, isA<Error<bool>>());
        expect((result as Error<bool>).error, isA<InvalidModelFileException>());
        // The bad file is never handed to the installer.
        verifyNever(packageService.install(any));
        // The controller returns to idle so the button is usable again.
        expect(controller.installStatus, ModelInstallControllerState.idle);
      },
    );

    test('accepts a path regardless of extension casing', () async {
      final controller = controllerWithPick('/tmp/model.ASRMODEL');
      when(packageService.install(any)).thenAnswer((_) async => 'My model');
      when(modelRepo.retrieveModels()).thenAnswer((_) async => Result.ok(null));

      final result = await controller.pickAndInstall();

      expect(result, isA<Ok<bool>>());
      expect((result as Ok<bool>).value, isTrue);
      verify(packageService.install(any)).called(1);
    });

    test('cancelling the picker reports no install without erroring', () async {
      final controller = controllerWithPick(null);

      final result = await controller.pickAndInstall();

      expect(result, isA<Ok<bool>>());
      expect((result as Ok<bool>).value, isFalse);
      verifyNever(packageService.install(any));
      expect(controller.installStatus, ModelInstallControllerState.idle);
    });

    test(
      'cancelling the picker notifies listeners so the UI can rebuild',
      () async {
        final controller = controllerWithPick(null);
        var notified = false;
        controller.addListener(() => notified = true);

        await controller.pickAndInstall();

        expect(notified, isTrue);
      },
    );
  });
}
