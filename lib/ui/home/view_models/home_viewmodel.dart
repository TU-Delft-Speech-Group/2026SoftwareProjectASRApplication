import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';

class RecordingTranscription {
  final String _label;
  String get label => _label;
  String content = '...';

  RecordingTranscription(this._label);
}

class HomeViewModel extends ChangeNotifier {
  final AudioRecorder _recorder;
  late final RecorderService _recorderService;

  HomeViewModel({AudioRecorder? recorder, RecorderService? recorderService})
    : _recorder = recorder ?? AudioRecorder() {
    _recorderService = recorderService ?? RecorderService(_recorder);
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
      _transcriptions.last.content =
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras sodales tellus ut viverra ultrices. Pellentesque leo nulla, placerat non gravida sit amet, sodales sed lectus.';
    }

    notifyListeners();
  }
}
