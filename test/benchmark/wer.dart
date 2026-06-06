// Word- and character-error-rate scoring for transcription benchmarks.
//
// Both metrics are Levenshtein distance over a token sequence (words or
// characters) divided by the reference length. Inputs are normalised first:
// lower-cased, ASCII punctuation stripped, whitespace collapsed.

class TranscriptScore {
  const TranscriptScore({
    required this.wer,
    required this.cer,
    required this.substitutions,
    required this.insertions,
    required this.deletions,
    required this.referenceWords,
  });

  final double wer;
  final double cer;
  final int substitutions;
  final int insertions;
  final int deletions;
  final int referenceWords;
}

TranscriptScore scoreTranscript(String reference, String hypothesis) {
  final refNorm = _normalise(reference);
  final hypNorm = _normalise(hypothesis);

  final refWords = refNorm.isEmpty ? const <String>[] : refNorm.split(' ');
  final hypWords = hypNorm.isEmpty ? const <String>[] : hypNorm.split(' ');
  final wordOps = _editOps<String>(refWords, hypWords);
  final wer = refWords.isEmpty
      ? (hypWords.isEmpty ? 0.0 : 1.0)
      : wordOps.distance / refWords.length;

  final refChars = refNorm.replaceAll(' ', '').split('');
  final hypChars = hypNorm.replaceAll(' ', '').split('');
  final charOps = _editOps<String>(refChars, hypChars);
  final cer = refChars.isEmpty
      ? (hypChars.isEmpty ? 0.0 : 1.0)
      : charOps.distance / refChars.length;

  return TranscriptScore(
    wer: wer,
    cer: cer,
    substitutions: wordOps.substitutions,
    insertions: wordOps.insertions,
    deletions: wordOps.deletions,
    referenceWords: refWords.length,
  );
}

String _normalise(String text) {
  final lowered = text.toLowerCase();
  final stripped = StringBuffer();
  for (final code in lowered.codeUnits) {
    final isLower = code >= 0x61 && code <= 0x7a;
    final isDigit = code >= 0x30 && code <= 0x39;
    final isSpace =
        code == 0x20 || code == 0x09 || code == 0x0a || code == 0x0d;
    // Non-ASCII letters pass through; the Gigaspeech vocab is ASCII-only but
    // ground-truth text may include UTF-8 letters from contributor edits.
    final isAsciiPunct = (code >= 0x21 && code <= 0x2f) ||
        (code >= 0x3a && code <= 0x40) ||
        (code >= 0x5b && code <= 0x60) ||
        (code >= 0x7b && code <= 0x7e);
    if (isAsciiPunct) {
      stripped.writeCharCode(0x20);
    } else if (isLower || isDigit || isSpace || code > 0x7f) {
      stripped.writeCharCode(code);
    }
  }
  return stripped.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

class _EditOps {
  const _EditOps({
    required this.distance,
    required this.substitutions,
    required this.insertions,
    required this.deletions,
  });
  final int distance;
  final int substitutions;
  final int insertions;
  final int deletions;
}

_EditOps _editOps<T>(List<T> ref, List<T> hyp) {
  final m = ref.length;
  final n = hyp.length;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= n; j++) {
    dp[0][j] = j;
  }
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (ref[i - 1] == hyp[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        final sub = dp[i - 1][j - 1] + 1;
        final ins = dp[i][j - 1] + 1;
        final del = dp[i - 1][j] + 1;
        dp[i][j] = sub < ins ? (sub < del ? sub : del) : (ins < del ? ins : del);
      }
    }
  }

  var i = m;
  var j = n;
  var subs = 0;
  var inss = 0;
  var dels = 0;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && ref[i - 1] == hyp[j - 1]) {
      i--;
      j--;
    } else if (i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + 1) {
      subs++;
      i--;
      j--;
    } else if (j > 0 && dp[i][j] == dp[i][j - 1] + 1) {
      inss++;
      j--;
    } else {
      dels++;
      i--;
    }
  }
  return _EditOps(
    distance: dp[m][n],
    substitutions: subs,
    insertions: inss,
    deletions: dels,
  );
}
