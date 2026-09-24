import 'dart:convert';
import 'dart:io';

/// Decodes Whisper token ids back to text using the OpenAI byte-level BPE
/// vocabulary shipped in tokenizer.json.
///
/// This is NOT sentencepiece: there is no word-boundary marker. Tokens are
/// byte-level and some represent raw UTF-8 bytes rather than characters.
class WhisperTokenizer {
  WhisperTokenizer._(this._idToToken);

  final Map<int, String> _idToToken;

  // Special token ids (Whisper-tiny defaults).
  static const int startOfTranscript = 50258;
  static const int endOfText = 50257;
  static const int transcribe = 50359;
  static const int noTimestamps = 50363;

  /// Language token id for a given language code (e.g. "en" -> 50259).
  static int languageToken(String lang) {
    const languages = [
      'en', 'zh', 'de', 'es', 'ru', 'ko', 'fr', 'ja', 'pt', 'tr',
      'pl', 'ca', 'nl', 'ar', 'sv', 'it', 'id', 'hi', 'fi', 'vi',
      'he', 'uk', 'el', 'ms', 'cs', 'ro', 'da', 'hu', 'ta', 'no',
      'th', 'ur', 'hr', 'bg', 'lt', 'la', 'mi', 'ml', 'cy', 'sk',
      'te', 'fa', 'lv', 'bn', 'sr', 'az', 'sl', 'kn', 'et', 'mk',
      'br', 'eu', 'is', 'hy', 'ne', 'mn', 'bs', 'kk', 'sq', 'sw',
      'gl', 'mr', 'pa', 'si', 'km', 'sn', 'yo', 'so', 'af', 'oc',
      'ka', 'be', 'tg', 'sd', 'gu', 'am', 'yi', 'lo', 'uz', 'fo',
      'ht', 'ps', 'tk', 'nn', 'mt', 'sa', 'lb', 'my', 'bo', 'tl',
      'mg', 'as', 'tt', 'haw', 'ln', 'ha', 'ba', 'jw', 'su', 'yue',
    ];
    final index = languages.indexOf(lang);
    return index >= 0 ? 50259 + index : 50259; // default to English
  }

  /// Loads the tokenizer from a tokenizer.json file (HuggingFace format).
  static Future<WhisperTokenizer> load(String path) async {
    final content = await File(path).readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    final model = json['model'] as Map<String, dynamic>;
    final vocab = model['vocab'] as Map<String, dynamic>;

    final idToToken = <int, String>{};
    for (final entry in vocab.entries) {
      idToToken[entry.value as int] = entry.key;
    }

    // Also add tokens from added_tokens if present.
    final addedTokens = json['added_tokens'] as List<dynamic>?;
    if (addedTokens != null) {
      for (final token in addedTokens) {
        final t = token as Map<String, dynamic>;
        idToToken[t['id'] as int] = t['content'] as String;
      }
    }

    return WhisperTokenizer._(idToToken);
  }

  /// Decodes a list of token ids to text, skipping special tokens
  /// and filtering Whisper's non-speech tags.
  String decode(List<int> tokenIds) {
    final buffer = StringBuffer();
    for (final id in tokenIds) {
      if (id >= 50257) continue; // skip all special tokens
      final token = _idToToken[id];
      if (token == null) continue;
      buffer.write(token);
    }
    // Whisper BPE uses byte-level encoding with special Unicode chars.
    // Convert the byte-mapped characters back to UTF-8 text.
    final text = _bytesToText(buffer.toString());
    return _filterNonSpeechTags(text);
  }

  /// Removes Whisper's non-speech annotations like [MUSIC], [BLANK_AUDIO],
  /// (air whooshing), etc. These are valid Whisper outputs but should not
  /// be shown to users in a captioning context.
  static final RegExp _tagPattern = RegExp(
    r'\[([^\]]*?)\]|\(([^)]*?)\)',
  );

  static String _filterNonSpeechTags(String text) {
    return text
        .replaceAll(_tagPattern, '')
        .replaceAll(RegExp(r'  +'), ' ')
        .trim();
  }

  /// The forced decoder prompt: [startOfTranscript, langToken, transcribe, noTimestamps].
  List<int> forcedDecoderIds(String language) {
    return [startOfTranscript, languageToken(language), transcribe, noTimestamps];
  }

  /// Whisper's BPE maps bytes 0-255 to Unicode codepoints. This reverses that.
  static String _bytesToText(String bpeText) {
    // The byte-to-unicode mapping from OpenAI's tokenizer.
    final bytes = <int>[];
    for (final codeUnit in bpeText.runes) {
      final byte = _unicodeToByte[codeUnit];
      if (byte != null) {
        bytes.add(byte);
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static final Map<int, int> _unicodeToByte = _buildUnicodeToByte();

  static Map<int, int> _buildUnicodeToByte() {
    // Reproduces openai/whisper bytes_to_unicode()
    final bs = <int>[
      ...List.generate(0x7E - 0x21 + 1, (i) => 0x21 + i),     // 33-126  printable ASCII
      ...List.generate(0xAC - 0xA1 + 1, (i) => 0xA1 + i),     // 161-172 Latin supplement
      ...List.generate(0xFF - 0xAE + 1, (i) => 0xAE + i),     // 174-255 Latin supplement cont.
    ];

    final cs = List<int>.from(bs);
    int n = 0;
    for (int b = 0; b < 256; b++) {
      if (!bs.contains(b)) {
        bs.add(b);
        cs.add(256 + n);
        n++;
      }
    }

    final map = <int, int>{};
    for (int i = 0; i < bs.length; i++) {
      map[cs[i]] = bs[i];
    }
    return map;
  }
}
