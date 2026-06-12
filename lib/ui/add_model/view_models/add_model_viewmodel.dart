import 'package:asr_application/utils/error_message.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';

class AddModelViewModel extends ChangeNotifier {
  AddModelViewModel({Future<Result<void>> Function()? onPickModel})
    : _onPickModelHandler = onPickModel;

  final Future<Result<void>> Function()? _onPickModelHandler;

  ErrorMessage? _modelPickError;
  ErrorMessage? get modelPickError => _modelPickError;

  Future<void> _onPickModel() async {
    if (_onPickModelHandler == null) return;

    final result = await _onPickModelHandler();
    switch (result) {
      case Ok():
        _modelPickError = null;
        break;
      case Error():
        _modelPickError = ErrorMessage(message: result.error.toString());
        break;
    }
    notifyListeners();
  }

  Future<void> Function()? get onPickModel =>
      _onPickModelHandler == null ? null : _onPickModel;
}
