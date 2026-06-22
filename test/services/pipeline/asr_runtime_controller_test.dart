// This file was AI generated, however it is properly reviewed and adjusted by a human before being pushed

import 'dart:async';

import 'package:asr_application/services/pipeline/asr_runtime_controller.dart';
import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/fakes/services/pipeline/fake_asr_runtime.dart';

void main() {
  group('AsrRuntimeController', () {
    test('starts empty', () {
      final controller = AsrRuntimeController(
        loadRuntime: (_) async {
          throw StateError('not used');
        },
      );

      expect(controller.runtime, isNull);
      expect(controller.modelName, isNull);
      expect(controller.error, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.hasRuntime, isFalse);
    });

    test('exposes loading state while a model is being loaded', () async {
      final runtime = FakeAsrRuntime();
      final completer = Completer<AsrRuntime>();
      final controller = AsrRuntimeController(
        loadRuntime: (_) => completer.future,
      );
      var notificationCount = 0;
      controller.addListener(() => notificationCount++);

      final load = controller.loadModel('model-a');

      expect(controller.isLoading, isTrue);
      expect(controller.runtime, isNull);
      expect(notificationCount, 1);

      completer.complete(runtime);
      await load;

      expect(controller.isLoading, isFalse);
      expect(controller.runtime, same(runtime));
      expect(notificationCount, 2);
    });

    test('sets runtime and model after successful load', () async {
      final runtime = FakeAsrRuntime();
      final controller = AsrRuntimeController(
        loadRuntime: (_) async => runtime,
      );

      await controller.loadModel('model-a');

      expect(controller.runtime, same(runtime));
      expect(controller.modelName, 'model-a');
      expect(controller.error, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.hasRuntime, isTrue);
    });

    test('successful model switch disposes the previous runtime', () async {
      final first = FakeAsrRuntime();
      final second = FakeAsrRuntime();
      var callCount = 0;
      final controller = AsrRuntimeController(
        loadRuntime: (_) async => ++callCount == 1 ? first : second,
      );

      await controller.loadModel('model-a');
      await controller.loadModel('model-b');

      expect(controller.runtime, same(second));
      expect(first.disposeCallCount, 1);
      expect(second.disposeCallCount, 0);
    });

    test('failed model switch keeps the previous runtime active', () async {
      final first = FakeAsrRuntime();
      final loadError = StateError('invalid downloaded model');
      var callCount = 0;
      final controller = AsrRuntimeController(
        loadRuntime: (_) async {
          callCount++;
          if (callCount == 1) return first;
          throw loadError;
        },
      );

      await controller.loadModel('model-a');
      await expectLater(
        controller.loadModel('model-b'),
        throwsA(same(loadError)),
      );

      expect(controller.runtime, same(first));
      expect(controller.error, same(loadError));
      expect(controller.isLoading, isFalse);
      expect(first.disposeCallCount, 0);
    });

    test('new load clears a previous error', () async {
      final loadError = StateError('temporary failure');
      final runtime = FakeAsrRuntime();
      var callCount = 0;
      final controller = AsrRuntimeController(
        loadRuntime: (_) async {
          callCount++;
          if (callCount == 1) throw loadError;
          return runtime;
        },
      );

      await expectLater(
        controller.loadModel('model-a'),
        throwsA(same(loadError)),
      );
      expect(controller.error, same(loadError));

      await controller.loadModel('model-a');

      expect(controller.error, isNull);
      expect(controller.runtime, same(runtime));
    });

    test('close disposes active runtime and clears state', () async {
      final runtime = FakeAsrRuntime();
      final controller = AsrRuntimeController(
        loadRuntime: (_) async => runtime,
      );
      await controller.loadModel('model-a');

      await controller.close();

      expect(runtime.disposeCallCount, 1);
      expect(controller.runtime, isNull);
      expect(controller.modelName, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.hasRuntime, isFalse);
    });

    test('close notifies listeners so the UI can react to the cleared runtime', () async {
      final runtime = FakeAsrRuntime();
      final controller = AsrRuntimeController(
        loadRuntime: (_) async => runtime,
      );
      await controller.loadModel('model-a');
      var notificationCount = 0;
      controller.addListener(() => notificationCount++);

      await controller.close();

      expect(notificationCount, 1);
    });
  });
}
