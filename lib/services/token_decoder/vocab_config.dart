/* the special token ids and text processing rules for a specific
  model's vocabulary; 
  different models (dutch, english, etc) may have different special 
  token ids and boundary marker conventions;
  TODO: when adding a new model, create a new VocabConfig instance with
  the correct ids and pass it to BpeTokenIdToTextService.load
*/
class VocabConfig {
  // token id for the unknown token (will be filtereed)
  final int unkId;
  // token id for start of sequence (will be filtered)
  final int sosId;
  // token id for end of sequence (will be filtered)
  final int eosId;
  // additional model-specific token IDs to supress (FIL, LAUGH, UNK filler tokens in Dutch CGN model)
  final Set<int> suppressedIds;
  // the string used by sentencepiece to mark word boundaries;
  // the standard sentencepiece uses is '▁' (U+2581);
  // set to null if the model does not use word boundary markers
  final String? wordBoundaryMarker;
  // bool value for whether to trim leading or trailing whitespace from the final result
  final bool trimResult;

  const VocabConfig({
    required this.unkId,
    required this.sosId,
    required this.eosId,
    this.suppressedIds = const {},
    this.wordBoundaryMarker = '▁',
    this.trimResult = true,
  });

  // dutch CGN ESPnet model (5000-token BPE, vocab.txt extracted from bpe.model)
  // 0  ~ <unk>
  // 1 ~ <s>
  // 2 ~ </s>
  // 3 ~ [FIL] (filler)
  // 4 ~ [LAUGH] (laughter marker)
  // 5 ~ [UNK] ( unknown spoken word)
  static const dutch = VocabConfig(
    unkId: 0,
    sosId: 1,
    eosId: 2,
    suppressedIds: {3, 4, 5},
    wordBoundaryMarker: '▁',
    trimResult: true,
  );

  // english ESPnet model (5000-token BPE, vocab.txt extracted from bpe.model)
  // 0  ~ <unk>
  // 1  ~ <s>
  // 2  ~ </s>
  static const english = VocabConfig(
    unkId: 0,
    sosId: 1,
    eosId: 2,
    suppressedIds: {},
    wordBoundaryMarker: '▁',
    trimResult: true,
  );

  // english Gigaspeech ESPnet model (5000-token BPE)
  // 0    ~ <blank> (CTC blank)
  // 1    ~ <unk>
  // 4999 ~ <sos/eos> (shared)
  static const englishGigaspeech = VocabConfig(
    unkId: 1,
    sosId: 4999,
    eosId: 4999,
    suppressedIds: {0},
    wordBoundaryMarker: '▁',
    trimResult: true,
  );

  // this checks if a token id is a special token that should be filtered out
  bool isSuppressed(int id) {
    return id == unkId || id == sosId || id == eosId || suppressedIds.contains(id);
  }
}