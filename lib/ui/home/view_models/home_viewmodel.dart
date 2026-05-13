import 'package:flutter/material.dart';

class HomeViewModel extends ChangeNotifier {
  bool _isTranscribing = false;

  bool get isTranscribing => _isTranscribing;

  void toggleTranscribing() {
    _isTranscribing = !_isTranscribing;
    notifyListeners();
  }
}
