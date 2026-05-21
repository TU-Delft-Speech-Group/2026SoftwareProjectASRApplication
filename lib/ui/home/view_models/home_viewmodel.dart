import 'dart:typed_data';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';
// TODO: when vocab file is in assets, uncomment and swap:
// import 'package:asr_application/services/token_decoder/bpe_token_id_to_text_service.dart';
// import 'package:asr_application/services/token_decoder/vocab_config.dart';


class RecordingTranscription {
  final String _label;
  String get label => _label;
  String content = '...';
  bool isDecoding = false;
  RecordingTranscription(this._label);
}

class HomeViewModel extends ChangeNotifier {
  final AudioRecorder _recorder;
  late final RecorderService _recorderService;
  late final TokenIdToTextService _textService;

  HomeViewModel({
    AudioRecorder? recorder,
    RecorderService? recorderService,
    TokenIdToTextService? textService,
  }) : _recorder = recorder ?? AudioRecorder() {
    _recorderService = recorderService ?? RecorderService(_recorder);
    // TODO: swap for BpeTokenIdToTextService
    _textService = textService ?? const StubTokenIdToTextService();
  }

  bool _isTranscribing = false;
  bool get isTranscribing => _isTranscribing;

  bool? _hasRecordingPermissions;
  bool? get hasRecordingPermissions => _hasRecordingPermissions;

  final List<RecordingTranscription> _transcriptions = [];
  List<RecordingTranscription> get recentTranscriptions => _transcriptions;

  Future<void> toggleTranscribing() async {
    if (_hasRecordingPermissions != true) {
      if (await _recorder.hasPermission()) {
        _hasRecordingPermissions = true;
      } else {
        _hasRecordingPermissions = false;
        notifyListeners();
        return;
      }
    }

    _isTranscribing = !_isTranscribing;

    if (_isTranscribing) {
      DateTime now = clock.now();
      String formattedDate = DateFormat('kk:mm').format(now);
      _transcriptions.add(RecordingTranscription(formattedDate));
      _recorderService.start();
    } else {
      // TODO: replace dummy Int32List with token ids from DecoderService:
      //   final tokenIds = await _decoderService.decode(logProbs, shape: shape);
      //   await _decodeTokenIds(_transcriptions.last, tokenIds);
      final dummyTokenIds = Int32List.fromList([55, 174, 199]);
      await _decodeTokenIds(_transcriptions.last, dummyTokenIds);
    }

    notifyListeners();
  }

  Future<void> _decodeTokenIds(RecordingTranscription transcription, Int32List tokenIds) async {
    transcription.isDecoding = true;
    notifyListeners();

    try {
      final result = await _textService.decode(tokenIds);
      transcription.content = result.text;
    } catch (error) {
      debugPrint('Token decoding failed: $error');
      transcription.content = 'Decoding failed.';
    } finally {
      transcription.isDecoding = false;
      notifyListeners();
    }
  }
}
