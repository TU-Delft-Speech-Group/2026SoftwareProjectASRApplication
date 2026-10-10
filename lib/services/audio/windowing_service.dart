import 'dart:core';
import 'dart:math';

import 'package:asr_application/services/audio/mel_service.dart';

import '../../exceptions/audio/window_function_size_incompatible_exception.dart';

class SampleWindow {
  final List<double> _samples;
  List<double> get samples => _samples;
  final List<double> _rawSamples;
  List<double> get rawSamples => _rawSamples;
  final List<double> _melEnergies;
  List<double> get melEnergies => _melEnergies;

  SampleWindow(this._samples, this._melEnergies, [this._rawSamples = const []]);
}

class WindowingService {
  int get windowLength => 400;
  int get hopLength => 160;
  int get _centerPad => windowLength ~/ 2;
  late final List<double> _windowFunction;
  List<double> get windowFunction => _windowFunction;
  late final MelService _melService = MelService();
  List<double> _buffer = <double>[];
  bool _leadingReflectInjected = false;

  WindowingService() {
    _windowFunction = WindowFunctionGenerator().hann(windowLength);
    if (windowFunction.length != windowLength) {
      throw WindowFunctionSizeIncompatibleException();
    }
  }

  List<SampleWindow> addSamples(List<double> samples, {bool flush = false}) {
    _buffer.addAll(samples);

    _maybeInjectLeadingReflect();

    final frames = _leadingReflectInjected ? extract() : <SampleWindow>[];

    if (flush) {
      frames.addAll(_flushTrailing());
    }

    return frames;
  }

  List<SampleWindow> extract() {
    final frames = <SampleWindow>[];

    while (_buffer.length >= windowLength) {
      frames.add(_createFrame(_buffer.sublist(0, windowLength)));
      _buffer.removeRange(0, hopLength);
    }

    return frames;
  }

  List<SampleWindow> stop() {
    final frames = _leadingReflectInjected ? extract() : <SampleWindow>[];
    frames.addAll(_flushTrailing());

    return frames;
  }

  void reset() {
    _buffer = <double>[];
    _leadingReflectInjected = false;
  }

  void _maybeInjectLeadingReflect() {
    if (_leadingReflectInjected) return;
    if (_buffer.length <= _centerPad) return;

    final reflect = _buffer
        .sublist(1, _centerPad + 1)
        .reversed
        .toList(growable: false);
    _buffer.insertAll(0, reflect);
    _leadingReflectInjected = true;
  }

  List<SampleWindow> _flushTrailing() {
    if (_buffer.isEmpty) return <SampleWindow>[];

    if (!_leadingReflectInjected) {
      _buffer.insertAll(0, List<double>.filled(_centerPad, 0.0));
      _leadingReflectInjected = true;
    }

    final available = _buffer.length - 1;
    final reflectLength = min(_centerPad, available);
    if (reflectLength > 0) {
      final reflect = _buffer
          .sublist(_buffer.length - 1 - reflectLength, _buffer.length - 1)
          .reversed
          .toList(growable: false);
      _buffer.addAll(reflect);
    }
    if (reflectLength < _centerPad) {
      _buffer.addAll(List<double>.filled(_centerPad - reflectLength, 0.0));
    }

    return extract();
  }

  SampleWindow _createFrame(List<double> samples) {
    final raw = List<double>.from(samples);
    for (int i = 0; i < windowLength; i++) {
      samples[i] *= windowFunction[i];
    }

    final mel = _melService.windowToMel(samples);
    return SampleWindow(samples, mel, raw);
  }
}

class WindowFunctionGenerator {
  List<double> hamming(int windowLength) {
    return List.generate(windowLength, (n) {
      return 0.54 - 0.46 * cos((2 * pi * n) / windowLength);
    });
  }

  List<double> hann(int windowLength) {
    return List.generate(windowLength, (n) {
      return 0.5 * (1 - cos(2 * pi * n / windowLength));
    });
  }
}
