import 'dart:typed_data';
import 'token_id_to_text_service.dart';

/* stub (not permanent), which returns raw token IDs as text until the vocab file is committed;
    TODO: once the vocab file is added to assets, replace this class with
    BpeTokenIdToTextService from bpe_token_id_to_text_service.dart
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