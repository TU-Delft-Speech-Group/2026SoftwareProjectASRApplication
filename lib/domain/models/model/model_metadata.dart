/// Vocabulary metadata read from an installed model's `manifest.json` ("vocab"
/// block, format version 2+). It carries the special-token ids the decoding
/// pipeline needs so that each model — not just the gigaspeech recipe — decodes
/// and detokenizes correctly.
///
/// Null on a [Model] means the package predates the metadata block (format
/// version 1); callers fall back to built-in defaults in that case.
class ModelMetadata {
  const ModelMetadata({
    required this.blankId,
    required this.unkId,
    required this.sosEosId,
    required this.suppressedIds,
    this.wordBoundaryMarker,
  });

  /// CTC blank token id.
  final int blankId;

  /// Unknown token id (filtered from decoded text).
  final int unkId;

  /// Shared start/end-of-sequence token id (filtered from decoded text).
  final int sosEosId;

  /// Token ids to drop from decoded text beyond unk/sos/eos: the blank plus any
  /// non-speech filler markers such as `[FIL]`, `[LAUGH]`, `[UNK]`. Always
  /// contains [blankId] — [fromManifest] folds it in so a manifest that omits
  /// the blank from its `suppressed_ids` list still can't leak it into text.
  final Set<int> suppressedIds;

  /// SentencePiece word-boundary marker (usually `▁`), or null when the model
  /// uses none.
  final String? wordBoundaryMarker;

  /// Parses the `vocab` object from a manifest. Returns null when the block is
  /// absent or malformed, so loading falls back to defaults rather than failing.
  static ModelMetadata? fromManifest(Map<String, dynamic> manifest) {
    final vocab = manifest['vocab'];
    if (vocab is! Map<String, dynamic>) return null;

    final blankId = vocab['blank_id'];
    final unkId = vocab['unk_id'];
    final sosEosId = vocab['sos_eos_id'];
    if (blankId is! int || unkId is! int || sosEosId is! int) return null;

    // Always suppress the blank, even if the manifest's list leaves it out.
    final rawSuppressed = vocab['suppressed_ids'];
    final suppressedIds = <int>{
      blankId,
      if (rawSuppressed is List) ...rawSuppressed.whereType<int>(),
    };

    return ModelMetadata(
      blankId: blankId,
      unkId: unkId,
      sosEosId: sosEosId,
      suppressedIds: suppressedIds,
      wordBoundaryMarker: vocab['word_boundary_marker'] as String?,
    );
  }
}
