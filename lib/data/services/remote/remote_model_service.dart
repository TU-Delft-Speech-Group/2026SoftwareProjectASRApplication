import 'dart:io';

import 'package:asr_application/exceptions/model/model_remote_exception.dart';
import 'package:asr_application/exceptions/model/model_storage_exception.dart';
import 'package:asr_application/config/remote_model_service.dart';
import 'package:asr_application/utils/result.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RemoteModelService {
  final RemoteModelServiceConfig _config;
  final Directory _remoteModelsDirectory;
  final HttpClient Function() _httpClientFactory;
  final File Function(String path) _fileFactory;

  RemoteModelService._({
    required RemoteModelServiceConfig config,
    required Directory remoteModelsDirectory,
    required HttpClient Function() httpClientFactory,
    required File Function(String path) fileFactory,
  }) : _config = config,
       _remoteModelsDirectory = remoteModelsDirectory,
       _httpClientFactory = httpClientFactory,
       _fileFactory = fileFactory;

  static Future<RemoteModelService> create({
    required RemoteModelServiceConfig config,
    HttpClient Function() httpClientFactory = HttpClient.new,
    Directory Function(String path) directoryFactory = Directory.new,
    File Function(String path) fileFactory = File.new,
  }) async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final remoteModelsDirectory = directoryFactory(
      p.join(appDirectory.path, config.directory),
    );

    if (!remoteModelsDirectory.existsSync()) {
      try {
        remoteModelsDirectory.createSync();
      } catch (err) {
        throw ModelStorageException(
          'Failed to create remote model directory: $err',
        );
      }
    }

    return RemoteModelService._(
      config: config,
      httpClientFactory: httpClientFactory,
      fileFactory: fileFactory,
      remoteModelsDirectory: remoteModelsDirectory,
    );
  }

  Future<Result<File>> downloadModel(String modelUrl) async {
    Uri uri;
    final parseResult = _parseModelUrl(modelUrl);
    switch (parseResult) {
      case Ok():
        uri = parseResult.value;
        break;
      case Error():
        return Result.error(parseResult.error);
    }

    final fileName = p.basename(uri.path);
    final filePath = p.join(_remoteModelsDirectory.path, fileName);
    final file = _fileFactory(filePath);
    if (await file.exists()) {
      return Result.ok(file);
    }

    final HttpClient client = _httpClientFactory();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        return Result.error(
          ModelRemoteException(
            'Failed to download model: status ${response.statusCode}',
          ),
        );
      }

      await response.pipe(file.openWrite());
    } catch (err) {
      return Result.error(
        ModelRemoteException('Failed to download model: $err'),
      );
    } finally {
      client.close();
    }

    return Result.ok(file);
  }

  Result<Uri> _parseModelUrl(String modelUrl) {
    Uri uri;
    try {
      uri = Uri.parse(modelUrl);
    } catch (err) {
      return Result.error(FormatException('Invalid URL format: $modelUrl'));
    }

    if (!_config.allowedHosts.contains(uri.host)) {
      return Result.error(
        ModelRemoteException('Host not allowed: ${uri.host}'),
      );
    }

    if (!_config.allowedExtensions.contains(p.extension(uri.path))) {
      return Result.error(
        ModelRemoteException('Unknown file type: ${p.extension(uri.path)}'),
      );
    }

    return Result.ok(uri);
  }
}
