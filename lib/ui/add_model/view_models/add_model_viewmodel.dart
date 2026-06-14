import 'package:asr_application/utils/error_message.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';

class AddModelViewModel extends ChangeNotifier {
  AddModelViewModel({
    Future<Result<void>> Function()? onPickModel,
    Future<Result<void>> Function(String modelUri)? onDownloadModel,
  }) : _onPickModelHandler = onPickModel,
       _onDownloadModelHandler = onDownloadModel;

  final Future<Result<void>> Function()? _onPickModelHandler;
  final Future<Result<void>> Function(String modelUri)? _onDownloadModelHandler;

  ErrorMessage? _addModelError;
  ErrorMessage? get addModelError => _addModelError;

  final TextEditingController modelUriTextController = TextEditingController();

  Future<void> _onPickModel() async {
    if (_onPickModelHandler == null) return;

    final result = await _onPickModelHandler();
    switch (result) {
      case Ok():
        _addModelError = null;
        break;
      case Error():
        _addModelError = ErrorMessage(message: result.error.toString());
        break;
    }
    notifyListeners();
  }

  Future<void> Function()? get onPickModel =>
      _onPickModelHandler == null ? null : _onPickModel;

  Future<void> _onDownloadModel() async {
    if (_onDownloadModelHandler == null) return;

    final result = await _onDownloadModelHandler(modelUriTextController.text);
    switch (result) {
      case Ok():
        _addModelError = null;
        break;
      case Error():
        _addModelError = ErrorMessage(message: result.error.toString());
        break;
    }
    notifyListeners();
  }

  Future<void> Function()? get onDownloadModel =>
      _onDownloadModelHandler == null ? null : _onDownloadModel;

  @override
  void dispose() {
    modelUriTextController.dispose();
    super.dispose();
  }
}
