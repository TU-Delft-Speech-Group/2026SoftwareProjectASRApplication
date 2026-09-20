import 'dart:math';
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

/// Computes log-mel spectrograms matching OpenAI Whisper's preprocessing.
///
/// Whisper expects: 16kHz audio -> STFT(n_fft=400, hop=160) -> 80 mel bands
/// -> log scale -> pad/truncate to 3000 frames -> shape [1, 80, 3000].
class WhisperMelService {
  WhisperMelService() : _fft = FFT(nFft) {
    _hannWindow = Float64List(nFft);
    for (int i = 0; i < nFft; i++) {
      _hannWindow[i] = 0.5 * (1.0 - cos(2.0 * pi * i / nFft));
    }
    _filterbank = _buildMelFilterbank();
  }

  static const int sampleRate = 16000;
  static const int nFft = 400;
  static const int hopLength = 160;
  static const int nMels = 80;
  static const int maxFrames = 3000; // 30 seconds

  final FFT _fft;
  late final Float64List _hannWindow;
  late final List<Float64List> _filterbank;

  /// Converts raw 16kHz audio samples to a Whisper mel spectrogram.
  ///
  /// Returns a [Float32List] of length [nMels * maxFrames] (80 * 3000 = 240000)
  /// laid out as [mel_band_0_frame_0, mel_band_0_frame_1, ...] i.e. row-major
  /// [nMels, maxFrames].
  Float32List compute(Float64List audio) {
    // Pad audio to at least one full frame.
    final padded = _padAudio(audio);

    // Number of STFT frames.
    final nFrames = (padded.length - nFft) ~/ hopLength + 1;
    final actualFrames = nFrames < maxFrames ? nFrames : maxFrames;

    // Compute STFT frame by frame.
    final melSpec = Float32List(nMels * maxFrames); // zero-padded

    for (int frame = 0; frame < actualFrames; frame++) {
      final offset = frame * hopLength;

      // Apply Hann window.
      final windowed = Float64List(nFft);
      for (int i = 0; i < nFft; i++) {
        windowed[i] = padded[offset + i] * _hannWindow[i];
      }

      // FFT.
      final fftResult = _fft.realFft(windowed);

      // Power spectrum (first nFft/2 + 1 bins).
      final nBins = nFft ~/ 2 + 1;
      final power = Float64List(nBins);
      final magnitudes = fftResult.squareMagnitudes();
      for (int i = 0; i < nBins; i++) {
        power[i] = magnitudes[i];
      }

      // Apply mel filterbank and log.
      for (int m = 0; m < nMels; m++) {
        double energy = 0.0;
        final filter = _filterbank[m];
        for (int b = 0; b < nBins; b++) {
          energy += power[b] * filter[b];
        }
        // Log mel energy (clamp to avoid log(0)).
        melSpec[m * maxFrames + frame] = log(max(energy, 1e-10)).toFloat();
      }
    }

    // Whisper normalizes: scale so max is 0, then shift by +4, clamp to >= 0,
    // then divide by 4. This matches whisper/audio.py log_mel_spectrogram.
    double maxVal = -1e20;
    for (int i = 0; i < melSpec.length; i++) {
      if (melSpec[i] > maxVal) maxVal = melSpec[i];
    }
    for (int i = 0; i < melSpec.length; i++) {
      melSpec[i] = (max((melSpec[i] - maxVal).toDouble(), -8.0) + 4.0) / 4.0;
    }

    return melSpec;
  }

  /// Pads audio with nFft/2 zeros on each side (matching librosa center padding)
  /// and ensures minimum length for at least one frame.
  Float64List _padAudio(Float64List audio) {
    final pad = nFft ~/ 2;
    final minLen = nFft + pad * 2;
    final totalLen = max(audio.length + pad * 2, minLen);
    final padded = Float64List(totalLen);
    for (int i = 0; i < audio.length; i++) {
      padded[i + pad] = audio[i];
    }
    return padded;
  }

  /// Builds an 80-band mel filterbank for nFft=400, sr=16000.
  /// Uses Slaney-style mel scale matching Whisper's Python implementation.
  List<Float64List> _buildMelFilterbank() {
    final nBins = nFft ~/ 2 + 1;
    const fMin = 0.0;
    const fMax = 8000.0; // Nyquist for 16kHz

    // FFT bin center frequencies.
    final fftFreqs = Float64List.fromList(
      List.generate(nBins, (i) => i * sampleRate / nFft),
    );

    // Mel scale: equally spaced points in mel, converted back to Hz.
    final melMin = _hzToMel(fMin);
    final melMax = _hzToMel(fMax);
    final melPoints = List.generate(
      nMels + 2,
      (i) => _melToHz(melMin + (melMax - melMin) * i / (nMels + 1)),
    );

    final filters = List.generate(nMels, (_) => Float64List(nBins));

    for (int m = 0; m < nMels; m++) {
      final fLow = melPoints[m];
      final fCenter = melPoints[m + 1];
      final fHigh = melPoints[m + 2];

      for (int b = 0; b < nBins; b++) {
        final freq = fftFreqs[b];
        if (freq >= fLow && freq <= fCenter && fCenter > fLow) {
          filters[m][b] = (freq - fLow) / (fCenter - fLow);
        } else if (freq > fCenter && freq <= fHigh && fHigh > fCenter) {
          filters[m][b] = (fHigh - freq) / (fHigh - fCenter);
        }
      }

      // Slaney normalization.
      final enorm = 2.0 / (fHigh - fLow);
      for (int b = 0; b < nBins; b++) {
        filters[m][b] *= enorm;
      }
    }

    return filters;
  }

  // Slaney-style mel scale (matches librosa default and Whisper).
  static const double _fSp = 200.0 / 3.0;
  static const double _minLogHz = 1000.0;
  static const double _minLogMel = _minLogHz / _fSp;
  static final double _logStep = log(6.4) / 27.0;

  static double _hzToMel(double hz) {
    if (hz < _minLogHz) return hz / _fSp;
    return _minLogMel + log(hz / _minLogHz) / _logStep;
  }

  static double _melToHz(double mel) {
    if (mel < _minLogMel) return mel * _fSp;
    return _minLogHz * exp(_logStep * (mel - _minLogMel));
  }
}

extension on double {
  double toFloat() => this;
}
