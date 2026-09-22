/// Vocabulary metadata read from an installed model's manifest.json ("vocab"
/// block, format version 2+).
class ModelMetadata {
  const ModelMetadata({
    this.engine = 'espnet',
    this.blankId,
    this.unkId,
    this.sosEosId,
    this.suppressedIds = const {},
    this.wordBoundaryMarker,
    this.language,
    this.task,
  });

  final String engine;
  final int? blankId;
  final int? unkId;
  final int? sosEosId;
  final Set<int> suppressedIds;
  final String? wordBoundaryMarker;
  final String? language;
  final String? task;

  bool get isEspnet => engine == 'espnet';
  bool get isWhisper => engine == 'whisper';

  static ModelMetadata? fromManifest(Map<String, dynamic> manifest) {
    final engine = manifest['engine'] as String? ?? 'espnet';
    final vocab = manifest['vocab'];

    if (engine == 'whisper') {
      final wv = vocab is Map<String, dynamic> ? vocab : <String, dynamic>{};
      return ModelMetadata(
        engine: 'whisper',
        language: wv['language'] as String? ?? 'en',
        task: wv['task'] as String? ?? 'transcribe',
      );
    }

    if (vocab is! Map<String, dynamic>) return null;
    final blankId = vocab['blank_id'];
    final unkId = vocab['unk_id'];
    final sosEosId = vocab['sos_eos_id'];
    if (blankId is! int || unkId is! int || sosEosId is! int) return null;

    final rawSuppressed = vocab['suppressed_ids'];
    final suppressedIds = <int>{
      blankId,
      if (rawSuppressed is List) ...rawSuppressed.whereType<int>(),
    };

    return ModelMetadata(
      engine: 'espnet',
      blankId: blankId,
      unkId: unkId,
      sosEosId: sosEosId,
      suppressedIds: suppressedIds,
      wordBoundaryMarker: vocab['word_boundary_marker'] as String?,
    );
  }
}
