import 'dart:typed_data';
 
// the result of a full decode pass
class DecodeResult {
  // this is the final joined and processed text
  final String text;
  // individual token ids before joining(for debugging)
  final Int32List tokenIds;
  const DecodeResult({required this.text, required this.tokenIds});
}

/* this is the contract between the decoder output (Int32List of token ids)
    and the text conversion layer. BpeTokenIdToTextService is the real,
    model-vocab-backed implementation; StubTokenIdToTextService is the
    no-op fallback used when no model vocab is available.
*/
abstract class TokenIdToTextService {
  /* decodes a flat list of token ids to a DecodeResult
    the implementations filter special tokens (blank, sos, eos, and other model-specific),
    map each remaining ID to its vocab piece, join the pieces and apply any model-specific 
    post-processing
  */
  Future<DecodeResult> decode(Int32List tokenIds);
}
