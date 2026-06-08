import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/exceptions/model/model_package_exception.dart';

class ModelPackageService {
  const ModelPackageService({
    required LocalModelService localModelService,
    required LocalModelStorageConfig config,
  }) : _localModelService = localModelService,
       _config = config;

  final LocalModelService _localModelService;
  final LocalModelStorageConfig _config;

  // Version 1: no vocab metadata block. Version 2: adds a "vocab" block with
  // special-token ids. Both install fine; the app falls back to built-in
  // defaults when the block is absent.
  static const _supportedFormatVersions = {'1', '2'};
  static const extension = '.asrmodel';

  /// Installs an .asrmodel package file into local model storage.
  ///
  /// Extracts the archive to a temp directory, verifies all SHA-256 checksums
  /// declared in manifest.json, then moves the files to the model directory.
  /// Returns the model name declared in the manifest.
  Future<String> install(File packageFile) async {
    if (!packageFile.path.endsWith(extension)) {
      throw const ModelPackageException('File must have .asrmodel extension');
    }
    if (!await packageFile.exists()) {
      throw ModelPackageException('File not found: ${packageFile.path}');
    }

    final tempDir = await Directory.systemTemp.createTemp('asrmodel_');
    try {
      // extractFileToDisk rejects custom extensions; decode directly instead.
      final inputStream = InputFileStream(packageFile.path);
      try {
        final archive = ZipDecoder().decodeBuffer(inputStream);
        await extractArchiveToDisk(archive, tempDir.path);
      } finally {
        await inputStream.close();
      }

      return await _verifyAndInstall(tempDir);
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<String> _verifyAndInstall(Directory tempDir) async {
    final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw const ModelPackageException('Missing manifest.json in package');
    }

    final manifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    _validateManifest(manifest);

    final modelName = manifest['model_name'] as String;
    final files = manifest['files'] as Map<String, dynamic>;

    for (final entry in files.entries) {
      final filename = entry.key;
      final info = entry.value as Map<String, dynamic>;
      final expectedHash = info['sha256'] as String;

      final extractedFile = File(p.join(tempDir.path, filename));
      if (!await extractedFile.exists()) {
        throw ModelPackageException(
          'File declared in manifest not found after extraction: $filename',
        );
      }

      final actualHash = await _sha256File(extractedFile);
      if (actualHash != expectedHash) {
        throw ModelPackageException('Checksum mismatch for $filename');
      }
    }

    final modelDir = await _localModelService.getModelDirectory(modelName);
    await _replaceModelDirectory(
      modelDir: modelDir,
      extractedDir: tempDir,
      packageFiles: files.keys,
    );

    return modelName;
  }

  Future<void> _replaceModelDirectory({
    required Directory modelDir,
    required Directory extractedDir,
    required Iterable<String> packageFiles,
  }) async {
    final modelRoot = modelDir.parent;
    final installRoot = Directory(p.join(modelRoot.parent.path, '.asrmodel'));
    await installRoot.create(recursive: true);

    final modelName = p.basename(modelDir.path);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final stagingDir = Directory(
      p.join(installRoot.path, '$modelName.installing-$suffix'),
    );
    final backupDir = Directory(
      p.join(installRoot.path, '$modelName.backup-$suffix'),
    );

    await stagingDir.create(recursive: true);

    try {
      await _copyModelFiles(
        sourceDir: extractedDir,
        destinationDir: stagingDir,
        packageFiles: packageFiles,
      );

      if (await modelDir.exists()) {
        await modelDir.rename(backupDir.path);
      }

      await stagingDir.rename(modelDir.path);

      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }
    } catch (_) {
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }

      if (await backupDir.exists() && !await modelDir.exists()) {
        await backupDir.rename(modelDir.path);
      }

      rethrow;
    }
  }

  Future<void> _copyModelFiles({
    required Directory sourceDir,
    required Directory destinationDir,
    required Iterable<String> packageFiles,
  }) async {
    final fileMapping = {
      'encoder.onnx': _config.encoderFilePath,
      'ctc.onnx': _config.ctcFilePath,
      'decoder.onnx': _config.decoderFilePath,
      'vocab.txt': _config.vocabFilePath,
    };

    for (final filename in packageFiles) {
      final destName = fileMapping[filename];
      if (destName == null) continue;
      final src = File(p.join(sourceDir.path, filename));
      await src.copy(p.join(destinationDir.path, destName));
    }

    // Preserve the manifest so the repository can read its vocab metadata
    // later. It is not listed in the manifest's own `files` map, so it is
    // copied separately rather than through the mapping above.
    final manifestSrc = File(p.join(sourceDir.path, 'manifest.json'));
    if (await manifestSrc.exists()) {
      await manifestSrc.copy(
        p.join(destinationDir.path, _config.manifestFilePath),
      );
    }
  }

  void _validateManifest(Map<String, dynamic> manifest) {
    final version = manifest['format_version'] as String?;
    if (!_supportedFormatVersions.contains(version)) {
      throw ModelPackageException(
        'Unsupported format version: $version '
        '(expected one of ${_supportedFormatVersions.join(', ')})',
      );
    }
    final name = manifest['model_name'] as String?;
    if (name == null || name.isEmpty) {
      throw const ModelPackageException('manifest.json is missing model_name');
    }
    final files = manifest['files'] as Map<String, dynamic>?;
    if (files == null) {
      throw const ModelPackageException('manifest.json is missing files map');
    }
    for (final required in ['encoder.onnx', 'ctc.onnx', 'vocab.txt']) {
      if (!files.containsKey(required)) {
        throw ModelPackageException(
          'manifest.json missing required file entry: $required',
        );
      }
    }
  }

  Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
