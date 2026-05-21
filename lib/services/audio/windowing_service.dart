import 'dart:core';

class SampleWindow {
  final List<double> _samples;
  List<double> get samples => _samples;

  SampleWindow(this._samples);
}

class WindowingService {
  int get windowLength => 400;
  int get hopLength => 160;
  late List<double> _buffer = [];

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

      // Apply windowing function.

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
