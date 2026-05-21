import 'dart:core';
import 'dart:math';

import '../../Exceptions/Audio/window_function_size_incompatible_exception.dart';

class SampleWindow {
  final List<double> _samples;
  List<double> get samples => _samples;

  SampleWindow(this._samples);
}

class WindowingService {
  int get windowLength => 400;
  int get hopLength => 160;
  late final List<double> _windowFunction;
  List<double> get windowFunction => _windowFunction;
  late List<double> _buffer = [];

  WindowingService() {
    _windowFunction = WindowFunctionGenerator().hann(windowLength);
    if (windowFunction.length != windowLength) {
      throw WindowFunctionSizeIncompatibleException();
    }
  }

  // Add incoming normalized PCM samples.
  List<SampleWindow> addSamples(List<double> samples) {
    // Append new samples.
    _buffer.addAll(samples);

    // Return created windows.
    return extract();
  }

  List<SampleWindow> extract() {
    final frames = <SampleWindow>[];

    // Extract overlapping frames.
    while (_buffer.length >= windowLength) {
      final frame = _buffer.sublist(0, windowLength);

      for (int i = 0; i < windowLength; i++) {
        frame[i] *= windowFunction[i];
      }

      // Add frame to list.
      frames.add(SampleWindow(frame));

      // Slide window (overlap).
      _buffer.removeRange(0, hopLength);
    }

    return frames;
  }

  List<SampleWindow> stop() {
    var frames = extract();

    // Pad the list with zero's until window size.
    if (_buffer.isNotEmpty) {
      _buffer.addAll(List.filled(windowLength - _buffer.length, 0));
    }

    // Add the last frames.
    frames.addAll(extract());

    return frames;
  }

  void reset() {
    _buffer = [];
  }
}

class WindowFunctionGenerator {
  List<double> hamming(int windowLength) {
    return List.generate(windowLength, (n) {
      return 0.54 - 0.46 * cos((2 * pi * n) / (windowLength - 1));
    });
  }

  List<double> hann(int windowLength) {
    return List.generate(windowLength, (n) {
      return 0.5 * (1 - cos(2 * pi * n / (windowLength - 1)));
    });
  }
}
