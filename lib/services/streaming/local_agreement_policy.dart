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
  const LocalAgreementPolicy({this.n = 2});

  // number of consecutive agreeing transcripts required for confirmation
  final int n;

  /* returns the confirmed word boundary prefix, or null when the n most
    recent transcripts do not agree on any shared prefix;
    transcripts is the full rolling history; 
    only the last n entries are inspected; 
    for fewer than n entries returns null
  */
  String? confirmedPrefix(List<String> transcripts) {
    if (transcripts.length < n) return null;

    final window = transcripts.sublist(transcripts.length - n);
    final shared = _commonPrefix(window);
    if (shared.isEmpty) return null;

    // the last word in the prefix is complete when every string in the window
    // has a space or ends exactly at the prefix boundary
    final lastWordComplete = window.every((s) {
      final next = shared.length;
      return next >= s.length || s[next] == ' ';
    });

    final String? candidate;
    if (lastWordComplete) {
      final trimmed = shared.trimRight();
      candidate = trimmed.isEmpty ? null : trimmed;
    } else {
      candidate = _trimToLastWordBoundary(shared);
    }

    if (candidate == null) return null;
    final result = candidate.trim();
    return result.isEmpty ? null : result;
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
