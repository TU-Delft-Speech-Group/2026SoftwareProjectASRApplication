/*
  local agreement (n) policy for streaming CTC transcription;
  given a rolling window of n consecutive transcripts, each produced after
  adding one new audio chunk to the processing buffer, a word boundary
  prefix is confirmed when all n transcripts share it as a common prefix;
  only whole word prefixes are confirmed;
  the prefix is accepted as is when the character immediately after it
  in every transcript is a space or end of string;
  otherwise it is trimmed back to the nearest preceeding space such that
  no partial word is ever committed
*/
class LocalAgreementPolicy {
  LocalAgreementPolicy({this.n = defaultN}) {
    if (n < 1) {
      throw ArgumentError('n must be >= 1 (got $n).');
    }
  }

  // Two consecutive agreeing transcripts is the minimum for stable output
  // without introducing noticeable latency.
  static const int defaultN = 2;

  final int n;

  // Returns the confirmed word boundary prefix, or null when the n most recent
  // transcripts do not agree on a shared non-empty prefix.
  // Inspects only the last n entries; returns null for fewer than n entries.
  String? confirmedPrefix(List<String> transcripts) {
    if (transcripts.length < n) return null;

    final window = transcripts.sublist(transcripts.length - n);
    final shared = _commonPrefix(window);
    if (shared.isEmpty) return null;

    final candidate = _resolveCandidate(window, shared);
    if (candidate == null) return null;

    final result = candidate.trim();
    return result.isEmpty ? null : result;
  }

  // Resolves the shared prefix to a confirmed candidate at a word boundary.
  // When the last word in the shared prefix is complete across the window,
  // the prefix is returned as is (trimmed of trailing whitespace).
  // Otherwise the prefix is trimmed back to the last internal word boundary.
  String? _resolveCandidate(List<String> window, String shared) {
    if (_isLastWordComplete(window, shared)) {
      final trimmed = shared.trimRight();
      return trimmed.isEmpty ? null : trimmed;
    }
    return _trimToLastWordBoundary(shared);
  }

  // The last word is complete when every transcript in the window either ends
  // at the prefix boundary or has a space immediately after it.
  bool _isLastWordComplete(List<String> window, String shared) {
    final prefixLen = shared.length;
    return window.every(
      (s) => prefixLen >= s.length || s[prefixLen] == ' ',
    );
  }

  String _commonPrefix(List<String> strings) {
    if (strings.isEmpty) return '';
    var prefix = strings.first;
    for (final s in strings.skip(1)) {
      var i = 0;
      while (i < prefix.length && i < s.length && prefix[i] == s[i]) {
        i++;
      }
      prefix = prefix.substring(0, i);
      if (prefix.isEmpty) return '';
    }
    return prefix;
  }

  /* trims text back to the last space so no partial word is confirmed;
    returns null when there is no full word in the prefix
  */
  String? _trimToLastWordBoundary(String text) {
    final boundary = text.lastIndexOf(' ');
    if (boundary <= 0) return null;
    return text.substring(0, boundary);
  }
}
