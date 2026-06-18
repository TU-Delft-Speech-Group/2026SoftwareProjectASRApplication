import 'dart:typed_data';
import 'token_id_to_text_service.dart';

/* no-op text service used when no real vocab is available: the
    no-model-loaded default in HomeViewModel, and a lightweight fake in
    tests. Returns raw token ids joined as text instead of real words;
    not meant to produce a usable transcript.
*/
class StubTokenIdToTextService implements TokenIdToTextService {
  const StubTokenIdToTextService();
  @override
  Future<DecodeResult> decode(Int32List tokenIds) async {
    return DecodeResult(text: tokenIds.join(' '), tokenIds: tokenIds,);
  }
  
  Future<String> decodeToString(Int32List tokenIds) async {
    return (await decode(tokenIds)).text;
  }

}