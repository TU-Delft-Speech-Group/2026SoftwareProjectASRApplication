import 'dart:io';

import 'package:asr_application/data/services/local/active_model_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActiveModelStore', () {
    late Directory tempDir;
    late ActiveModelStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('active_model_store_');
      store = ActiveModelStore(documentsDir: () async => tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('get returns null when no file has been written', () async {
      expect(await store.get(), isNull);
    });

    test('set then get round-trips the model name', () async {
      await store.set('EnglishGigaspeechConformerFBank_M01Libri100');
      expect(
        await store.get(),
        'EnglishGigaspeechConformerFBank_M01Libri100',
      );
    });

    test('set null deletes the persisted file', () async {
      await store.set('something');
      expect(await store.get(), 'something');
      await store.set(null);
      expect(await store.get(), isNull);
    });

    test('get returns null when the file is malformed', () async {
      final file = File('${tempDir.path}/active_model.json');
      await file.writeAsString('not json');
      expect(await store.get(), isNull);
    });

    test('get returns null when the name field is missing', () async {
      final file = File('${tempDir.path}/active_model.json');
      await file.writeAsString('{"other":"value"}');
      expect(await store.get(), isNull);
    });
  });
}
