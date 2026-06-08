import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;

import 'package:asr_application/config/local_model_storage.dart';
import 'package:asr_application/data/services/local/local_model_service.dart';
import 'package:asr_application/data/services/local/model_package_service.dart';
import 'package:asr_application/exceptions/model/model_package_exception.dart';

@GenerateNiceMocks([MockSpec<LocalModelService>()])
import 'model_package_service_test.mocks.dart';

// Stable dummy bytes for each file slot so hashes are deterministic.
final _encoderBytes = List<int>.generate(64, (i) => i);
final _ctcBytes = List<int>.generate(64, (i) => 255 - i);
final _vocabBytes = utf8.encode('<blank>\n<unk>\n▁hello\n▁world\n');
final _decoderBytes = List<int>.generate(64, (i) => i ^ 0xAA);

/// Builds a valid .asrmodel ZIP in memory.
///
/// [includeDecoder] adds decoder.onnx to both the manifest and the archive.
/// [skipInArchive] names a file that is declared in the manifest but left
///   out of the actual ZIP (simulates a corrupt/incomplete archive).
/// [corruptChecksum] replaces the SHA-256 of the named file with garbage.
/// [formatVersion] overrides the format_version field in the manifest.
/// [modelName] overrides the model_name field in the manifest.
List<int> buildTestPackage({
  String modelName = 'TestModel',
  String formatVersion = '1',
  bool includeDecoder = false,
  String? skipInArchive,
  String? corruptChecksum,
  Map<String, dynamic>? vocab,
}) {
  final content = <String, List<int>>{
    'encoder.onnx': _encoderBytes,
    'ctc.onnx': _ctcBytes,
    'vocab.txt': _vocabBytes,
    if (includeDecoder) 'decoder.onnx': _decoderBytes,
  };

  String checksumFor(String name, List<int> bytes) {
    if (corruptChecksum == name) return 'deadbeef' * 8;
    return sha256.convert(bytes).toString();
  }

  final fileEntries = {
    for (final e in content.entries)
      e.key: {
        'required': e.key != 'decoder.onnx',
        'sha256': checksumFor(e.key, e.value),
      },
  };

  final manifest = {
    'format_version': formatVersion,
    'model_name': modelName,
    'has_decoder': includeDecoder,
    'vocab': ?vocab,
    'files': fileEntries,
  };

  final archive = Archive();
  final manifestBytes = utf8.encode(jsonEncode(manifest));
  archive.addFile(
    ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
  );

  for (final entry in content.entries) {
    if (entry.key == skipInArchive) continue;
    archive.addFile(
      ArchiveFile(entry.key, entry.value.length, entry.value),
    );
  }

  return ZipEncoder().encode(archive)!;
}

void main() {
  late MockLocalModelService mockLocalModelService;
  late LocalModelStorageConfig config;
  late ModelPackageService service;

  // Temp directories cleaned up after each test.
  late Directory testRoot;
  late Directory modelDir;

  setUp(() async {
    mockLocalModelService = MockLocalModelService();
    config = const LocalModelStorageConfig();
    service = ModelPackageService(
      localModelService: mockLocalModelService,
      config: config,
    );

    testRoot = await Directory.systemTemp.createTemp('asrmodel_test_');
    modelDir = Directory(p.join(testRoot.path, 'installed_model'));
    await modelDir.create();

    when(
      mockLocalModelService.getModelDirectory(any),
    ).thenAnswer((_) async => modelDir);
  });

  tearDown(() async {
    if (await testRoot.exists()) {
      await testRoot.delete(recursive: true);
    }
  });

  Future<File> writePackage(List<int> bytes, {String name = 'test.asrmodel'}) async {
    final file = File(p.join(testRoot.path, name));
    await file.writeAsBytes(bytes);
    return file;
  }

  group('ModelPackageService', () {
    group('install — happy path', () {
      test('returns model name from manifest (no decoder)', () async {
        final pkg = await writePackage(buildTestPackage(modelName: 'MyModel'));

        final name = await service.install(pkg);

        expect(name, 'MyModel');
      });

      test('returns model name from manifest (with decoder)', () async {
        final pkg = await writePackage(
          buildTestPackage(modelName: 'MyModel', includeDecoder: true),
        );

        final name = await service.install(pkg);

        expect(name, 'MyModel');
      });

      test('extracts required files to model directory', () async {
        final pkg = await writePackage(buildTestPackage());

        await service.install(pkg);

        expect(
          File(p.join(modelDir.path, config.encoderFilePath)).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(modelDir.path, config.ctcFilePath)).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(modelDir.path, config.vocabFilePath)).existsSync(),
          isTrue,
        );
      });

      test('does not write decoder.onnx when package has no decoder', () async {
        final pkg = await writePackage(buildTestPackage(includeDecoder: false));

        await service.install(pkg);

        expect(
          File(p.join(modelDir.path, config.decoderFilePath)).existsSync(),
          isFalse,
        );
      });

      test('extracts decoder to model directory when present', () async {
        final pkg = await writePackage(
          buildTestPackage(includeDecoder: true),
        );

        await service.install(pkg);

        expect(
          File(p.join(modelDir.path, config.decoderFilePath)).existsSync(),
          isTrue,
        );
      });

      test('installed file bytes match original content', () async {
        final pkg = await writePackage(buildTestPackage());

        await service.install(pkg);

        final installedEncoder = await File(
          p.join(modelDir.path, config.encoderFilePath),
        ).readAsBytes();
        expect(installedEncoder, _encoderBytes);

        final installedVocab = await File(
          p.join(modelDir.path, config.vocabFilePath),
        ).readAsBytes();
        expect(installedVocab, _vocabBytes);
      });

      test('preserves manifest.json in the model directory', () async {
        final pkg = await writePackage(
          buildTestPackage(
            modelName: 'WithMeta',
            formatVersion: '2',
            vocab: {
              'blank_id': 0,
              'unk_id': 1,
              'sos_eos_id': 4999,
              'suppressed_ids': [0, 2, 3, 4],
              'word_boundary_marker': '▁',
            },
          ),
        );

        final name = await service.install(pkg);
        expect(name, 'WithMeta');

        final manifestFile = File(
          p.join(modelDir.path, config.manifestFilePath),
        );
        expect(manifestFile.existsSync(), isTrue);

        final manifest =
            jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        expect(manifest['format_version'], '2');
        expect(
          (manifest['vocab'] as Map<String, dynamic>)['suppressed_ids'],
          [0, 2, 3, 4],
        );
      });
    });

    group('install — validation errors', () {
      test('throws when file does not have .asrmodel extension', () async {
        final pkg = await writePackage(buildTestPackage(), name: 'model.zip');

        expect(
          () => service.install(pkg),
          throwsA(isA<ModelPackageException>()),
        );
      });

      test('throws when manifest.json is missing from archive', () async {
        final archive = Archive();
        final bytes = utf8.encode('dummy');
        archive.addFile(ArchiveFile('encoder.onnx', bytes.length, bytes));
        final zipBytes = ZipEncoder().encode(archive)!;
        final pkg = await writePackage(zipBytes);

        expect(
          () => service.install(pkg),
          throwsA(isA<ModelPackageException>()),
        );
      });

      test('throws on unsupported format_version', () async {
        final pkg = await writePackage(
          buildTestPackage(formatVersion: '99'),
        );

        expect(
          () => service.install(pkg),
          throwsA(isA<ModelPackageException>()),
        );
      });

      test('throws when manifest is missing a required file entry', () async {
        // Build a package whose manifest omits ctc.onnx entirely.
        final content = <String, List<int>>{
          'encoder.onnx': _encoderBytes,
          'vocab.txt': _vocabBytes,
        };
        final manifest = {
          'format_version': '1',
          'model_name': 'BadModel',
          'has_decoder': false,
          'files': {
            for (final e in content.entries)
              e.key: {
                'required': true,
                'sha256': sha256.convert(e.value).toString(),
              },
          },
        };
        final archive = Archive();
        final manifestBytes = utf8.encode(jsonEncode(manifest));
        archive.addFile(
          ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
        );
        for (final e in content.entries) {
          archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
        }
        final pkg = await writePackage(ZipEncoder().encode(archive)!);

        expect(
          () => service.install(pkg),
          throwsA(isA<ModelPackageException>()),
        );
      });

      test('throws on SHA-256 checksum mismatch', () async {
        final pkg = await writePackage(
          buildTestPackage(corruptChecksum: 'encoder.onnx'),
        );

        expect(
          () => service.install(pkg),
          throwsA(isA<ModelPackageException>()),
        );
      });

      test('throws when a file declared in manifest is absent from archive', () async {
        final pkg = await writePackage(
          buildTestPackage(skipInArchive: 'ctc.onnx'),
        );

        expect(
          () => service.install(pkg),
          throwsA(isA<ModelPackageException>()),
        );
      });
    });
  });
}
