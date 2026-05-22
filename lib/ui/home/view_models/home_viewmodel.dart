import 'dart:async';
import 'dart:typed_data';

import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/decoder/decoder_service.dart';
import 'package:asr_application/services/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';

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
  late final StreamingTranscriptionService _streamingService;

  Timer? _chunkTimer;
  bool _isProcessingChunk = false;
  // Words confirmed by local agreement only ever extend within a segment, so
  // the UI never has to retract text mid-segment.
  String _lockedText = '';

  // Commit the current segment after this much continuous silence; lines the
  // segment boundary up with a natural speech pause instead of the timer cap.
  static const int _pauseCommitMs = 1500;

  /*
  encodeBuffer: supply a real EncodeBuffer wrapping EspnetEncoderService
  textService: supply BpeTokenIdToTextService.load(...); defaults to stub
  */
  HomeViewModel({
    AudioRecorder? recorder,
    RecorderService? recorderService,
    EncodeBuffer? encodeBuffer,
    TokenIdToTextService? textService,
    StreamingTranscriptionService? streamingService,
  }) : _recorder = recorder ?? AudioRecorder() {
    _recorderService = recorderService ?? RecorderService(_recorder);
    _textService = textService ?? const StubTokenIdToTextService();

    _streamingService = streamingService ?? StreamingTranscriptionService(
      encode: encodeBuffer ?? _noopEncode,
      decoder: const DecoderService(),
      textService: _textService,
    );
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
      final now = clock.now();
      final label = DateFormat('kk:mm').format(now);
      _transcriptions.add(RecordingTranscription(label));

      _lockedText = '';
      _streamingService.reset();
      await _recorderService.start();

      // process a chunk on every tick so the UI updates while recording
      _chunkTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _processChunk(),
      );
    } else {
      _chunkTimer?.cancel();
      _chunkTimer = null;

      await _recorderService.stop();
      await _processChunk();
      _finalizeTranscription(_transcriptions.last);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _chunkTimer?.cancel();
    super.dispose();
  }

  /* runs the local agreement pipeline for the current audio buffer; */
  Future<void> _processChunk() async {
    if (_isProcessingChunk) return;
    _isProcessingChunk = true;

    try {
      final rawFrames = _tryCollectFrames();
      debugPrint(
        'HomeViewModel._processChunk: collected ${rawFrames?.length ?? 0} frames',
      );
      if (rawFrames == null || _transcriptions.isEmpty) return;

      final transcription = _transcriptions.last;
      transcription.isDecoding = true;
      notifyListeners();

      final result = await _streamingService.process(rawFrames);
      debugPrint(
        'HomeViewModel._processChunk: hypothesis="${result?.hypothesis ?? ''}" '
        'confirmed="${result?.confirmedText ?? ''}"',
      );
      if (result != null) {
        if (result.confirmedText.length > _lockedText.length &&
            result.confirmedText.startsWith(_lockedText)) {
          _lockedText = result.confirmedText;
        }

        final pauseTriggered =
            _recorderService.silenceDurationMs >= _pauseCommitMs &&
                _lockedText.isNotEmpty;

        if (result.sentenceConfirmed) {
          final committed = result.confirmedText.length > _lockedText.length
              ? result.confirmedText
              : _lockedText;
          _commitSegment(transcription, committed);
        } else if (pauseTriggered) {
          _commitSegment(transcription, _lockedText);
          _streamingService.commit();
        } else {
          transcription.content = result.hypothesis.startsWith(_lockedText)
              ? result.hypothesis
              : _lockedText.isNotEmpty
                  ? _lockedText
                  : result.hypothesis;
        }
      }
    } finally {
      if (_transcriptions.isNotEmpty) {
        _transcriptions.last.isDecoding = false;
      }
      _isProcessingChunk = false;
      notifyListeners();
    }
  }

  void _commitSegment(RecordingTranscription transcription, String text) {
    transcription.content = text;
    _lockedText = '';
    final label = DateFormat('kk:mm').format(clock.now());
    _transcriptions.add(RecordingTranscription(label));
  }

  List<Float32List>? _tryCollectFrames() {
    final frames = _recorderService.frames;
    if (frames.isEmpty) return null;
    return frames.map((w) => Float32List.fromList(w.melEnergies)).toList();
  }

  void _finalizeTranscription(RecordingTranscription transcription) {
    if (transcription.content != '...') return;
    // fall back to last confirmed text, or empty if nothing was confirmed
    transcription.content = _streamingService.confirmedText;
  }

  /* placeholder : shape [0, 2] produces an empty token list without
    triggering the decoder's blankId-out-of-range guard (needs blankId < vocab)
  */
  static Future<(List<double>, List<int>)> _noopEncode(
    List<Float32List> _,
  ) async =>
      (const <double>[], const <int>[0, 2]);
}
