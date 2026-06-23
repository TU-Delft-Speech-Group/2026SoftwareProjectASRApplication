import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/services/audio/vad_service.dart';
import 'package:asr_application/services/engines/espnet/decoder/decoder_service.dart';
import 'package:asr_application/services/engines/espnet/streaming/streaming_transcription_service.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';
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
  String tentativeContent = '';
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
    AsrTranscriptionService? streamingService,
    RecordingCoordinator? coordinator,
    List<RecordingTranscription> initialTranscriptions = const [],
    bool hasActiveModel = true,
  }) : _recorder = recorder ?? AudioRecorder(),
       _hasActiveModel = hasActiveModel {
    _transcriptions.addAll(initialTranscriptions);
    _isUsingVocabFallback = streamingService == null && textService == null;
    final recSvc =
        recorderService ?? RecorderService(_recorder, vadService: vadService);
    final textSvc = textService ?? const StubTokenIdToTextService();
    final AsrTranscriptionService streamSvc =
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

  Future<void> initialize() async {
    _initializationError = null;
    try {
      await _coordinator.initialize();
    } catch (error) {
      _initializationError = error;
      dev.log(
        'Recording pipeline initialization failed: $error',
        name: 'HomeViewModel',
        level: 800,
      );
      notifyListeners();
    }
  }

  final AudioRecorder _recorder;
  late final RecordingCoordinator _coordinator;

  StreamSubscription<RecordingEvent>? _eventSub;
  bool _isTranscribing = false;
  Object? _recordingError;
  Object? _initializationError;
  bool _isUsingVocabFallback = false;

  final bool _hasActiveModel;
  bool get hasActiveModel => _hasActiveModel;

  bool? _hasRecordingPermissions;
  bool? get hasRecordingPermissions => _hasRecordingPermissions;

  bool get isTranscribing => _isTranscribing;
  Object? get recordingError => _recordingError;
  Object? get initializationError => _initializationError;
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
      case HypothesisUpdated(:final confirmedText, :final tentativeText):
        current.content = confirmedText;
        current.tentativeContent = tentativeText;
      case SegmentCommitted(:final text):
        current.content = text;
        current.tentativeContent = '';
        _transcriptions.add(RecordingTranscription(_timeLabel()));
      case RecordingFailed(:final error):
        current.isDecoding = false;
        if (current.isPending) current.content = '';
        current.tentativeContent = '';
        _recordingError = error;
        _isTranscribing = false;
        final sub = _eventSub;
        _eventSub = null;
        scheduleMicrotask(() => sub?.cancel());
    }
    notifyListeners();
  }

  // Finalizes the last entry when the session ends. A still-pending entry takes
  // the coordinator's final confirmed text as a fallback (empty when the session
  // produced no output). Otherwise any muted tail is folded into the content so
  // the last spoken words are not dropped when recording stops.
  void _finalizeLastTranscription(String fallback) {
    if (_transcriptions.isEmpty) return;
    final last = _transcriptions.last;
    if (last.isPending) {
      last.content = fallback;
    } else if (last.tentativeContent.isNotEmpty) {
      last.content = '${last.content}${last.tentativeContent}';
    }
    last.tentativeContent = '';
  }

  String _timeLabel() => DateFormat('kk:mm').format(clock.now());

  static Future<(List<double>, List<int>, TransformerDecoderRunner?)>
  _noopEncode(List<Float32List> _) async =>
      (const <double>[], const <int>[0, 2], null);
}
