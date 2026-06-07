import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;

// Layout matches Kaldi/ESPnet recipes: each language directory holds a `text`
// file mapping utterance ids to ground-truth transcripts, plus the WAV files
// named `<id>.wav` next to it.
//
// Loaded via rootBundle so the same code works under `flutter test`, on
// macOS/iOS/Android integration tests, and across CI runners — none of those
// have the project root as their working directory.
class CorpusEntry {
  const CorpusEntry({
    required this.id,
    required this.language,
    required this.assetPath,
    required this.groundTruth,
  });

  final String id;
  final String language;
  // Flutter asset key for the WAV file. Resolve via rootBundle.load.
  final String assetPath;
  final String groundTruth;

  Future<Uint8List> loadWavBytes() async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

class Corpus {
  const Corpus._(this.entries);

  final List<CorpusEntry> entries;

  static const _languageSets = <_LanguageSet>[
    _LanguageSet(language: 'English', setDir: 'assets/audio/English/Spon0513'),
    _LanguageSet(language: 'Dutch', setDir: 'assets/audio/Dutch/Spon0513'),
  ];

  static Future<Corpus> load() async {
    final entries = <CorpusEntry>[];
    for (final ls in _languageSets) {
      entries.addAll(await _loadSet(ls));
    }
    return Corpus._(entries);
  }

  static Future<List<CorpusEntry>> _loadSet(_LanguageSet ls) async {
    final String raw;
    try {
      raw = await rootBundle.loadString('${ls.setDir}/text');
    } on FlutterError {
      return const [];
    }

    final out = <CorpusEntry>[];
    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final split = line.indexOf(' ');
      if (split <= 0) continue;
      final id = line.substring(0, split);
      final transcript = line.substring(split + 1).trim();
      out.add(CorpusEntry(
        id: id,
        language: ls.language,
        assetPath: '${ls.setDir}/$id.wav',
        groundTruth: transcript,
      ));
    }
    return out;
  }

  List<CorpusEntry> forLanguage(String language) =>
      entries.where((e) => e.language == language).toList();
}

class _LanguageSet {
  const _LanguageSet({required this.language, required this.setDir});
  final String language;
  final String setDir;
}
