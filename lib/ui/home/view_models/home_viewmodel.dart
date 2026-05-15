import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecordingTranscription {
  final String _label;
  String get label => _label;
  String content = '...';

  RecordingTranscription(this._label);
}

class HomeViewModel extends ChangeNotifier {
  bool _isTranscribing = false;

  bool get isTranscribing => _isTranscribing;

  final List<RecordingTranscription> _transcriptions = [];

  List<RecordingTranscription> get recentTranscriptions => _transcriptions;

  void toggleTranscribing() {
    _isTranscribing = !_isTranscribing;

    if (_isTranscribing) {
      DateTime now = clock.now();
      String formattedDate = DateFormat('kk:mm').format(now);
      _transcriptions.add(RecordingTranscription(formattedDate));
    } else {
      _transcriptions.last.content =
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras sodales tellus ut viverra ultrices. Pellentesque leo nulla, placerat non gravida sit amet, sodales sed lectus.';
    }

    notifyListeners();
  }
}
