import 'dart:io';

import 'package:asr_application/config/remote_model_service.dart';
import 'package:asr_application/data/services/remote/remote_model_service.dart';
import 'package:asr_application/exceptions/model/model_remote_exception.dart';
import 'package:asr_application/exceptions/model/model_storage_exception.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../../testing/fakes/dependencies/fake_path_provider.dart';
import '../../../../testing/utils/paramaterize.dart';
import '../../../../testing/utils/result.dart';

@GenerateNiceMocks([MockSpec<HttpClient>()])
@GenerateNiceMocks([MockSpec<HttpClientRequest>()])
@GenerateNiceMocks([MockSpec<HttpClientResponse>()])
@GenerateNiceMocks([MockSpec<Directory>()])
@GenerateNiceMocks([MockSpec<File>()])
import 'remote_model_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient mockHttpClient;
  late MockHttpClient Function() httpClientFactory;
  late MockDirectory mockDirectory;
  late MockDirectory Function(String path) directoryFactory;
  late MockFile mockFile;
  late MockFile Function(String path) fileFactory;

  setUp(() {
    mockHttpClient = MockHttpClient();
    httpClientFactory = () => mockHttpClient;
    mockDirectory = MockDirectory();
    directoryFactory = (path) => mockDirectory;
    mockFile = MockFile();
    fileFactory = (path) => mockFile;
  });

  group('RemoteModelService', () {
    setUp(() async {
      PathProviderPlatform.instance = FakePathProviderPlatform();
    });

    group('create', () {
      test('returns a RemoteModelService instance', () async {
        final service = await RemoteModelService.create(
          config: RemoteModelServiceConfig(),
          httpClientFactory: httpClientFactory,
          directoryFactory: directoryFactory,
          fileFactory: fileFactory,
        );

        expect(service, isA<RemoteModelService>());
      });

      test('creates the remote model directory if it does not exist', () async {
        final mockDirectory = MockDirectory();
        when(mockDirectory.existsSync()).thenReturn(false);
        when(mockDirectory.createSync()).thenReturn(null);

        await RemoteModelService.create(
          config: RemoteModelServiceConfig(),
          directoryFactory: (path) => mockDirectory,
        );

        verify(mockDirectory.createSync()).called(1);
      });

      test(
        'does not try to create the remote model directory if it does exist',
        () async {
          final mockDirectory = MockDirectory();
          when(mockDirectory.existsSync()).thenReturn(true);
          when(mockDirectory.createSync()).thenReturn(null);

          await RemoteModelService.create(
            config: RemoteModelServiceConfig(),
            directoryFactory: (path) => mockDirectory,
          );

          verifyNever(mockDirectory.createSync());
        },
      );

      test(
        'throws ModelStorageException if directory creation fails',
        () async {
          final mockDirectory = MockDirectory();
          when(mockDirectory.existsSync()).thenReturn(false);
          when(
            mockDirectory.createSync(),
          ).thenThrow(Exception('Failed to create directory'));

          await expectLater(
            () async => await RemoteModelService.create(
              config: RemoteModelServiceConfig(),
              directoryFactory: (path) => mockDirectory,
            ),
            throwsA(isA<ModelStorageException>()),
          );

          verify(mockDirectory.existsSync()).called(1);
          verify(mockDirectory.createSync()).called(1);
        },
      );
    });

    group('downloadModel', () {
      late RemoteModelService service;

      setUp(() async {
        service = await RemoteModelService.create(
          config: RemoteModelServiceConfig(allowedHosts: {'huggingface.co'}),
          directoryFactory: directoryFactory,
          fileFactory: fileFactory,
          httpClientFactory: httpClientFactory,
        );
      });

      test('returns FormatException for an invalid URL', () async {
        final result = await service.downloadModel('htt[]p:/example.com');

        expect(result, isA<Error>());
        expect(result.asError.error, isA<FormatException>());
      });

      each('unknown host', [
        'http://hugging.co/',
        'http://hugging.co/',
        'http://huggingface.com/',
      ])((host) {
        test('returns ModelRemoteException for unknown host: $host', () async {
          final result = await service.downloadModel(host);

          expect(result, isA<Error>());
          expect(result.asError.error, isA<ModelRemoteException>());
        });
      });

      each('allowed host', [
        'http://huggingface.co/',
        'http://user.huggingface.co/',
        'https://huggingface.co/',
        'https://user.huggingface.co/',
      ])((url) {
        test('returns ModelRemoteException for unknown host: $url', () async {
          final result = await service.downloadModel(url);

          expect(result, isA<Error>());
          expect(result.asError.error, isA<ModelRemoteException>());
        });
      });

      each('invalid extension', [
        'http://huggingface.co/model',
        'http://huggingface.co/.asrmodel.zip',
        'http://huggingface.co/asrmodel',
        'http://huggingface.co/model.asrmodel/model.zip',
      ])((url) {
        test(
          'returns ModelRemoteException for invalid extension: $url',
          () async {
            final result = await service.downloadModel(url);

            expect(result, isA<Error>());
            expect(result.asError.error, isA<ModelRemoteException>());
          },
        );
      });

      test('returns Ok<File> for a valid URL', () async {
        final mockResponse = MockHttpClientResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.pipe(any)).thenAnswer((_) async {});

        final mockRequest = MockHttpClientRequest();
        when(mockRequest.close()).thenAnswer((_) async => mockResponse);
        when(mockHttpClient.getUrl(any)).thenAnswer((_) async => mockRequest);

        final result = await service.downloadModel(
          'http://huggingface.co/model.asrmodel',
        );

        expect(result, isA<Ok>());
        expect(result.asOk.value, isA<File>());
      });

      test('returns Error if download fails', () async {
        final mockResponse = MockHttpClientResponse();
        when(mockResponse.statusCode).thenReturn(500);
        when(mockResponse.pipe(any)).thenAnswer((_) async {});

        final mockRequest = MockHttpClientRequest();
        when(mockRequest.close()).thenAnswer((_) async => mockResponse);
        when(mockHttpClient.getUrl(any)).thenAnswer((_) async => mockRequest);

        final result = await service.downloadModel(
          'http://huggingface.co/model.asrmodel',
        );

        expect(result, isA<Error>());
        expect(result.asError.error, isA<ModelRemoteException>());
      });

      test('writes response to file', () async {
        final mockResponse = MockHttpClientResponse();
        when(mockResponse.statusCode).thenReturn(200);
        when(mockResponse.pipe(any)).thenAnswer((_) async {});

        final mockRequest = MockHttpClientRequest();
        when(mockRequest.close()).thenAnswer((_) async => mockResponse);
        when(mockHttpClient.getUrl(any)).thenAnswer((_) async => mockRequest);

        final result = await service.downloadModel(
          'http://huggingface.co/model.asrmodel',
        );

        expect(result, isA<Ok>());
        verify(mockResponse.pipe(any)).called(1);
        verify(mockFile.openWrite()).called(1);
      });
    });
  });
}
