import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'token_id_to_text_service.dart';
import 'vocab_config.dart';

/* BPE vocab implementation using the sentencepiece vocab file;
  uses a VocabConfig to handle model-specific special tokens and post-processing;
  the decode method accepts the Int32List that DecoderService.decode returns;
  the implementation assumes a text vocab file where each line represents one token
  and the line number is the token id
*/
class BpeTokenIdToTextService implements TokenIdToTextService {
  final List<String> _vocab;
  final VocabConfig config;
  BpeTokenIdToTextService._(this._vocab, {required this.config}) {
    final marker = config.wordBoundaryMarker;
    if (marker != null && marker.isEmpty) {
      throw ArgumentError(
        'VocabConfig.wordBoundaryMarker must be null or non-empty — '
        'an empty string causes replaceAll to insert spaces between every character.',
      );
    }
  }

  factory BpeTokenIdToTextService.fromVocab(
    List<String> vocab, {
    required VocabConfig config,
  }) => BpeTokenIdToTextService._(vocab, config: config);

  /* this is loading the vocab from a Flutter asset;
    TODO: replace hardcoded asset path and default config once model
    loading is dynamic (path and VocabConfig determined by
    whichever model is active)
  */
  static Future<BpeTokenIdToTextService> load(
    String assetPath, {
    VocabConfig config = VocabConfig.english,
    AssetBundle? bundle,
  }) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    final vocab = raw.split('\n').where((line) => line.isNotEmpty).toList();
    if (vocab.isEmpty) {
      throw ArgumentError(
        'Vocabulary file at "$assetPath" is empty or contains no valid entries.',
      );
    }
    dev.log(
      'loaded: $assetPath (${vocab.length} tokens)',
      name: 'BpeTokenDecoder',
    );
    return BpeTokenIdToTextService._(vocab, config: config);
  }

  /* resolves a single token id to its vocab piece;
    returns '[unk:ID]' for ids outside the vocab range
  */
  String _idToPiece(int id) {
    if (id < 0 || id >= _vocab.length) return '[unk:$id]';
    return _vocab[id];
  }

  /* postprocess the raw joined string into text;
    TODO: if a new model uses a different boundary convention extend
    this method with a switch on config.wordBoundaryMarker
  */
  String _postProcess(String raw) {
    var result = raw;
    if (config.wordBoundaryMarker != null) {
      result = result.replaceAll(config.wordBoundaryMarker!, ' ');
    }
    if (config.trimResult) {
      result = result.trim();
    }
    // precaution for any accidental double spaces from filtering
    result = result.replaceAll(RegExp(r' {2,}'), ' ');

    return result;
  }

  /* this is converting the token IDs into text;
    it filters out special tokens and maps each id to its entry in the vocab;
  */
  @override
  Future<DecodeResult> decode(Int32List tokenIds) async {
    // filter special tokens, and map to pieces
    final filteredIds = Int32List.fromList(
      tokenIds.where((id) => !config.isSuppressed(id)).toList(),
    );
    // join the raw pieces
    final rawJoined = filteredIds.map((id) => _idToPiece(id)).join();
    // process into text
    final text = _postProcess(rawJoined);
    return DecodeResult(text: text, tokenIds: filteredIds);
  }

  Future<String> decodeToString(Int32List tokenIds) async {
    return (await decode(tokenIds)).text;
  }
}
