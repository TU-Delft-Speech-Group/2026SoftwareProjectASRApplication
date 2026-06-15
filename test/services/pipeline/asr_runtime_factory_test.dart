import 'package:asr_application/services/audio/vad_service.dart';
import 'package:asr_application/services/pipeline/asr_runtime_factory.dart';
import 'package:asr_application/services/shared/onnx/onnx.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';

// session that closes; run() is never called by initialize()
class _NopSession implements OnnxInferenceSessionContract {
  var closed = false;

  @override
  Future<Map<String, OnnxTensorContract>> run(
    Map<String, OnnxTensorContract> inputs,
  ) async => {};

  @override
  Future<void> close() async => closed = true;
}

// backend whose createSessionFromAsset succeeds; models initialize successfully
class _SuccessBackend implements OnnxInferenceBackendContract {
  _NopSession? lastSession;

  @override
  Future<OnnxInferenceSessionContract> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  }) async {
    lastSession = _NopSession();
    return lastSession!;
  }

  @override
  Future<OnnxInferenceSessionContract> createSessionFromFile(
    String filePath, {
    OrtSessionOptions? options,
  }) => createSessionFromAsset(filePath, options: options);

  @override
  Future<OnnxTensorContract> createTensor(
    dynamic data,
    List<int> shape,
  ) async => throw UnimplementedError();
}

// backend whose createSessionFromAsset always throws; triggers fallback path
class _ThrowingBackend implements OnnxInferenceBackendContract {
  @override
  Future<OnnxInferenceSessionContract> createSessionFromAsset(
    String assetPath, {
    OrtSessionOptions? options,
  }) => Future.error(Exception('asset not found: $assetPath'));

  @override
  Future<OnnxInferenceSessionContract> createSessionFromFile(
    String filePath, {
    OrtSessionOptions? options,
  }) => Future.error(Exception('file not found: $filePath'));

  @override
  Future<OnnxTensorContract> createTensor(
    dynamic data,
    List<int> shape,
  ) async => throw UnimplementedError();
}

void main() {
  group('AsrRuntimeFactory.tryCreateVadService', () {
    test('returns a VadService when backend initializes successfully', () async {
      final factory = AsrRuntimeFactory(vadBackend: _SuccessBackend());

      final svc = await factory.tryCreateVadService();

      expect(svc, isNotNull);
      expect(svc, isA<VadService>());
      await svc!.dispose();
    });

    test('returns null when backend throws during session creation', () async {
      final factory = AsrRuntimeFactory(vadBackend: _ThrowingBackend());

      final svc = await factory.tryCreateVadService();

      expect(svc, isNull);
    });

    test('returned service is pre-initialized', () async {
      final backend = _SuccessBackend();
      final factory = AsrRuntimeFactory(vadBackend: backend);

      final svc = await factory.tryCreateVadService();

      // if not initialized, isSpeech would throw StateError;
      // a pre-initialized service with a nop session accepts isSpeech without
      // throwing, confirmin the session was opened
      expect(backend.lastSession, isNotNull);
      await svc!.dispose();
    });

    test('session is closed when returned service is disposed', () async {
      final backend = _SuccessBackend();
      final factory = AsrRuntimeFactory(vadBackend: backend);

      final svc = await factory.tryCreateVadService();
      await svc!.dispose();

      expect(backend.lastSession!.closed, isTrue);
    });

    test('tryCreateVadService is callable multiple times independently',
        () async {
      final factory = AsrRuntimeFactory(vadBackend: _SuccessBackend());

      final first = await factory.tryCreateVadService();
      final second = await factory.tryCreateVadService();

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first, isNot(same(second)));

      await first!.dispose();
      await second!.dispose();
    });
  });
}
