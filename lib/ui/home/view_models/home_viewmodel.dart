import 'dart:async';
import 'dart:typed_data';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/audio/vad_service.dart';
import 'package:asr_application/services/token_decoder/stub_token_id_to_text_service.dart';
import 'package:asr_application/services/token_decoder/token_id_to_text_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'recording_coordinator.dart';

export 'recording_coordinator.dart'
    show
        RecordingCoordinator,
        RecordingEvent,
        DecodingStarted,
        DecodingFinished,
        HypothesisUpdated,
        SegmentCommitted,
        RecordingFailed;

class RecordingTranscription {
  static const _pending = '...';

  RecordingTranscription(this.label);

  final String label;
  String content = _pending;
  bool isDecoding = false;

  bool get isPending => content == _pending;
}

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    AudioRecorder? recorder,
    RecorderService? recorderService,
    VadService? vadService,
    EncodeBuffer? encodeBuffer,
    TokenIdToTextService? textService,
    StreamingTranscriptionService? streamingService,
    RecordingCoordinator? coordinator,
    List<RecordingTranscription> initialTranscriptions = const [],
    bool hasActiveModel = true,
  })  : _recorder = recorder ?? AudioRecorder(),
        _hasActiveModel = hasActiveModel {
    _transcriptions.addAll(initialTranscriptions);
    _isUsingVocabFallback = streamingService == null && textService == null;
    final recSvc =
        recorderService ?? RecorderService(_recorder, vadService: vadService);
    final textSvc = textService ?? const StubTokenIdToTextService();
    final streamSvc =
        streamingService ??
        StreamingTranscriptionService(
          encode: encodeBuffer ?? _noopEncode,
          decoder: const DecoderService(),
          textService: textSvc,
        );
    _coordinator =
        coordinator ??
        RecordingCoordinator(recorder: recSvc, streaming: streamSvc);
  }

  Future<void> initialize() => _coordinator.initialize();

  final AudioRecorder _recorder;
  late final RecordingCoordinator _coordinator;

  StreamSubscription<RecordingEvent>? _eventSub;
  bool _isTranscribing = false;
  Object? _recordingError;
  bool _isUsingVocabFallback = false;

  final bool _hasActiveModel;
  bool get hasActiveModel => _hasActiveModel;

  bool? _hasRecordingPermissions;
  bool? get hasRecordingPermissions => _hasRecordingPermissions;

  bool get isTranscribing => _isTranscribing;
  Object? get recordingError => _recordingError;
  bool get isUsingVocabFallback => _isUsingVocabFallback;

  final List<RecordingTranscription> _transcriptions = [];
  List<RecordingTranscription> get recentTranscriptions =>
      List.unmodifiable(_transcriptions);

  Future<void> toggleTranscribing() async {
    if (!await _ensurePermission()) return;
    if (_isTranscribing) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _coordinator.dispose();
    super.dispose();
  }

  Future<bool> _ensurePermission() async {
    if (_hasRecordingPermissions == true) return true;
    final granted = await _recorder.hasPermission();
    _hasRecordingPermissions = granted;
    if (!granted) notifyListeners();
    return granted;
  }

  Future<void> _startRecording() async {
    _recordingError = null;
    _transcriptions.add(RecordingTranscription(_timeLabel()));
    _isTranscribing = true;
    _eventSub = _coordinator.events.listen(_handleEvent);
    try {
      await _coordinator.start();
    } catch (error) {
      _eventSub?.cancel();
      _eventSub = null;
      _transcriptions.removeLast();
      _isTranscribing = false;
      _recordingError = error;
    }
  }

  Future<void> _stopRecording() async {
    try {
      final fallback = await _coordinator.stop();
      _eventSub?.cancel();
      _eventSub = null;
      _finalizeLastTranscription(fallback);
      _isTranscribing = false;
    } catch (error) {
      _eventSub?.cancel();
      _eventSub = null;
      _finalizeLastTranscription('');
      _isTranscribing = false;
      _recordingError = error;
    }
  }

  void _handleEvent(RecordingEvent event) {
    if (_transcriptions.isEmpty) return;
    final current = _transcriptions.last;
    switch (event) {
      case DecodingStarted():
        current.isDecoding = true;
      case DecodingFinished():
        current.isDecoding = false;
      case HypothesisUpdated(:final displayText):
        current.content = displayText;
      case SegmentCommitted(:final text):
        current.content = text;
        _transcriptions.add(RecordingTranscription(_timeLabel()));
      case RecordingFailed(:final error):
        current.isDecoding = false;
        if (current.isPending) current.content = '';
        _recordingError = error;
        _isTranscribing = false;
        final sub = _eventSub;
        _eventSub = null;
        scheduleMicrotask(() => sub?.cancel());
    }
    notifyListeners();
  }

  // Sets the content of the last entry if it never received committed text.
  // Uses the coordinator's final confirmed text as a fallback; falls back to
  // empty string when the session produced no output at all.
  void _finalizeLastTranscription(String fallback) {
    if (_transcriptions.isEmpty) return;
    final last = _transcriptions.last;
    if (last.isPending) last.content = fallback;
  }

  String _timeLabel() => DateFormat('kk:mm').format(clock.now());

  static Future<(List<double>, List<int>, TransformerDecoderRunner?)>
  _noopEncode(List<Float32List> _) async =>
      (const <double>[], const <int>[0, 2], null);
}
