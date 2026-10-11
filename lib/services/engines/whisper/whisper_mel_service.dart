import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

/// Computes log-mel spectrograms matching OpenAI Whisper's preprocessing.
///
/// Matches librosa / whisper/audio.py exactly:
///   STFT(n_fft=400, hop=160, center=True, pad_mode=reflect)
///   -> power spectrum -> mel filterbank -> log10 -> normalize
class WhisperMelService {
  /// [nMels] is 80 for tiny..medium and 128 for large-v3 / turbo. A loaded
  /// [filterbank] decides it (one row per mel bin).
  WhisperMelService({List<List<double>>? filterbank, int nMels = 80})
      : _customFilterbank = filterbank,
        nMels = filterbank?.length ?? nMels;

  static const int sampleRate = 16000;
  static const int nFft = 400;
  static const int hopLength = 160;
  final int nMels;
  static const int maxFrames = 3000;
  static const int nFftBins = nFft ~/ 2 + 1; // 201

  final List<List<double>>? _customFilterbank;
  late final FFT _fft = FFT(nFft);
  late final Float64List _hannWindow = _buildHannWindow();
  List<List<double>>? _filterbank;

  /// Loads the pre-computed mel filterbank from a JSON file.
  /// This guarantees exact match with librosa.
  static Future<WhisperMelService> fromFilterbankFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString());
      final weights = (json['weights'] as List)
          .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
          .toList();
      return WhisperMelService(filterbank: weights);
    }
    // Fall back to computed filterbank
    return WhisperMelService();
  }

  List<List<double>> get filterbank {
    _filterbank ??= _customFilterbank ?? _buildMelFilterbank();
    return _filterbank!;
  }

  /// Converts raw 16kHz audio to Whisper mel spectrogram [nMels, maxFrames].
  Float32List compute(Float64List audio) {
    // Whisper pads the audio with zeros to 30 s before the STFT. Append up to
    // one window of zeros so the frames at the end of the speech see the same
    // samples; the frames after that are pure padding and keep the silence
    // floor set below, without computing their FFTs.
    final tail = max(0, min(nFft, maxFrames * hopLength - audio.length));
    final extended = Float64List(audio.length + tail)
      ..setRange(0, audio.length, audio);

    // 1. Reflect-pad by nFft/2 on each side (matches librosa center=True)
    final padded = _reflectPad(extended, nFft ~/ 2);

    // 2. Compute STFT frames
    final nFrames = (padded.length - nFft) ~/ hopLength + 1;
    final actualFrames = min(nFrames, maxFrames);

    // log10 of the 1e-10 floor: what Whisper's zero padding becomes. Filling
    // with 0.0 instead made the padding the loudest part of the input.
    final melSpec = Float64List(nMels * maxFrames)
      ..fillRange(0, nMels * maxFrames, -10.0);

    final fb = filterbank;

    for (int frame = 0; frame < actualFrames; frame++) {
      final offset = frame * hopLength;

      // Apply Hann window
      final windowed = Float64List(nFft);
      for (int i = 0; i < nFft; i++) {
        windowed[i] = padded[offset + i] * _hannWindow[i];
      }

      // FFT -> power spectrum
      final fftResult = _fft.realFft(windowed);
      final magnitudes = fftResult.squareMagnitudes();

      // Apply mel filterbank
      for (int m = 0; m < nMels; m++) {
        double energy = 0.0;
        final filter = fb[m];
        for (int b = 0; b < nFftBins; b++) {
          energy += magnitudes[b] * filter[b];
        }
        // KEY FIX: log10, not natural log
        melSpec[m * maxFrames + frame] = log(max(energy, 1e-10)) / ln10;
      }
    }

    // Normalize exactly like whisper/audio.py:
    //   log = max(log, log.max() - 8); log = (log + 4) / 4
    double maxVal = -1e20;
    for (int i = 0; i < melSpec.length; i++) {
      if (melSpec[i] > maxVal) maxVal = melSpec[i];
    }
    final result = Float32List(nMels * maxFrames);
    for (int i = 0; i < melSpec.length; i++) {
      result[i] = (max(melSpec[i], maxVal - 8.0) + 4.0) / 4.0;
    }
    return result;
  }

  /// Reflect-pad: [1,2,3,4] with pad=2 -> [3,2,1,2,3,4,3,2]
  Float64List _reflectPad(Float64List audio, int pad) {
    final len = audio.length;
    if (len == 0) return Float64List(pad * 2);
    final out = Float64List(len + pad * 2);

    // Left reflect padding
    for (int i = 0; i < pad; i++) {
      final idx = pad - i;
      out[i] = idx < len ? audio[idx] : audio[0];
    }

    // Copy original
    for (int i = 0; i < len; i++) {
      out[i + pad] = audio[i];
    }

    // Right reflect padding
    for (int i = 0; i < pad; i++) {
      final idx = len - 2 - i;
      out[len + pad + i] = idx >= 0 ? audio[idx] : audio[len - 1];
    }

    return out;
  }

  Float64List _buildHannWindow() {
    final w = Float64List(nFft);
    for (int i = 0; i < nFft; i++) {
      // Periodic Hann window (matches librosa/scipy)
      w[i] = 0.5 * (1.0 - cos(2.0 * pi * i / nFft));
    }
    return w;
  }

  /// Builds Slaney-style mel filterbank matching librosa exactly.
  List<List<double>> _buildMelFilterbank() {
    final fftFreqs = List<double>.generate(
      nFftBins,
      (i) => i * sampleRate.toDouble() / nFft,
    );

    // Mel-spaced center frequencies
    final melPoints = List<double>.generate(
      nMels + 2,
      (i) => _melToHz(_hzToMel(0.0) + (_hzToMel(8000.0) - _hzToMel(0.0)) * i / (nMels + 1)),
    );

    final filters = List.generate(nMels, (_) => List<double>.filled(nFftBins, 0.0));

    final fDiff = List<double>.generate(
      melPoints.length - 1,
      (i) => melPoints[i + 1] - melPoints[i],
    );

    for (int m = 0; m < nMels; m++) {
      for (int b = 0; b < nFftBins; b++) {
        final lower = -(melPoints[m] - fftFreqs[b]) / fDiff[m];
        final upper = (melPoints[m + 2] - fftFreqs[b]) / fDiff[m + 1];
        filters[m][b] = max(0.0, min(lower, upper));
      }
      // Slaney normalization
      final enorm = 2.0 / (melPoints[m + 2] - melPoints[m]);
      for (int b = 0; b < nFftBins; b++) {
        filters[m][b] *= enorm;
      }
    }

    return filters;
  }

  // Slaney mel scale (matches librosa default)
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
