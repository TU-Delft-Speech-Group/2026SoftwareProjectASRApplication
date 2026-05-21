import 'dart:math';
import 'dart:typed_data';

import 'package:asr_application/Exceptions/Audio/filterbank_shape_incompatible.dart';
import 'package:fftea/fftea.dart';

import '../../Exceptions/Audio/window_size_incompatible_with_target_fft.dart';

class MelService {
  final MelHelper melHelper = MelHelper();

  /// @todo make the constants dependant on the loaded model.
  int get nFft => 512;
  late final FFT _fftHandler = FFT(nFft);
  double get fMin => 0.0;
  double get fMax => 8_000.0;
  double get sampleRate => 16_000.0;
  int get nMelEnergies => 80;
  late final _filterbank = melHelper.generateFilterbank(
    fMin,
    fMax,
    nMelEnergies,
    nFft,
    sampleRate,
    false,
  );

  List<double> windowToMel(List<double> window) {
    final fftWindow = melHelper.centerPad(window, nFft);
    final fft = _fftHandler.realFft(fftWindow);
    final powerSpectrum = melHelper.powerSpectrum(fft);
    final amplitudeSpectrum = powerSpectrum
        .map((p) => sqrt(p < 1e-10 ? 1e-10 : p))
        .toList();
    return melHelper.applyMelFilters(amplitudeSpectrum, _filterbank, true);
  }
}

class MelHelper {
  double log10(double x) => log(x) / ln10;

  /// @see https://librosa.org/doc/0.11.0/_modules/librosa/core/convert.html
  double hzToMel(double freq, {required bool htk}) {
    if (htk) {
      return 2595.0 * log10(1.0 + freq / 700.0);
    }

    // Slaney-style mel scale
    const double fSp = 200.0 / 3.0;
    const double minLogHz = 1000.0;
    const double minLogMel = minLogHz / fSp;
    final double logStep = log(6.4) / 27.0;

    if (freq < minLogHz) {
      return freq / fSp;
    }

    return minLogMel + log(freq / minLogHz) / logStep;
  }

  /// @see https://librosa.org/doc/0.11.0/_modules/librosa/core/convert.html
  double melToHz(double mel, {required bool htk}) {
    if (htk) {
      return 700.0 * (pow(10.0, mel / 2595.0) - 1.0);
    }

    // Slaney-style inverse mel scale
    const double fSp = 200.0 / 3.0;
    const double minLogHz = 1000.0;
    const double minLogMel = minLogHz / fSp;
    final double logStep = log(6.4) / 27.0;

    if (mel < minLogMel) {
      return mel * fSp;
    }

    return minLogHz * exp(logStep * (mel - minLogMel));
  }

  List<double> centerPad(List<double> window, int targetLength) {
    // pad the window left and right equally with 0's until a the list is of size finalSize
    if (window.length > targetLength) {
      throw WindowSizeIncompatibleWithTargetFft();
    }

    final totalPadding = targetLength - window.length;
    final leadingPadding = totalPadding ~/ 2;
    final trailingPadding = totalPadding - leadingPadding;

    return <double>[
      ...List<double>.filled(leadingPadding, 0.0),
      ...window,
      ...List<double>.filled(trailingPadding, 0.0),
    ];
  }

  /// @see https://github.com/espnet/espnet/blob/29a4df6492ff4ffef7b00e27eda9f4cffca22b4b/espnet2/layers/log_mel.py#L9
  /// @see https://librosa.org/doc/0.11.0/_modules/librosa/filters.html.
  List<List<double>> generateFilterbank(
    double fMin, // Lowest frequency [Hz].
    double fMax, // Highest frequency [Hz].
    int nMels, // Number of Mel bands to generate.
    int nFft, // Number of FFT components.
    double sampleRate, // Sample rate of the incoming signal.
    bool htk, // True to use HTK normalisation else use Slaney normalisation.
  ) {
    final numBins = nFft ~/ 2 + 1;

    // FFT bin center frequencies
    final fftFrequencies = List<double>.generate(
      numBins,
      (i) => i * sampleRate / nFft,
    );

    // Calculate Mel frequency equivalents
    final melMin = hzToMel(fMin, htk: htk);
    final melMax = hzToMel(fMax, htk: htk);

    // Create equally spaced points in mel space and convert it back to frequency.
    List<double> melPoints = List.generate(
      nMels + 2,
      (i) => melMin + (melMax - melMin) * i / (nMels + 1),
    );
    List<double> melFrequencies = melPoints
        .map((v) => melToHz(v, htk: htk))
        .toList();

    // Filterbank matrix shape for pointwise multiplication.
    List<List<double>> weights = List.generate(
      nMels,
      (_) => List.filled(numBins, 0.0),
    );

    // Calculate the filterbank
    final fDiff = List<double>.generate(
      melFrequencies.length - 1,
      (i) => melFrequencies[i + 1] - melFrequencies[i],
    );

    for (int i = 0; i < nMels; i++) {
      for (int j = 0; j < numBins; j++) {
        final lower = -(melFrequencies[i] - fftFrequencies[j]) / fDiff[i];
        final upper =
            (melFrequencies[i + 2] - fftFrequencies[j]) / fDiff[i + 1];

        weights[i][j] = max(0.0, min(lower, upper));
      }
    }

    final enorm = List<double>.generate(
      nMels,
      (i) => 2.0 / (melFrequencies[i + 2] - melFrequencies[i]),
    );

    for (int i = 0; i < nMels; i++) {
      for (int j = 0; j < numBins; j++) {
        weights[i][j] *= enorm[i];
      }
    }

    return weights;
  }

  List<double> powerSpectrum(Float64x2List frame) {
    int half = frame.length ~/ 2 + 1;
    final powers = frame.squareMagnitudes();

    return List.generate(half, (i) {
      return powers[i];
    });
  }

  List<double> applyMelFilters(
    List<double> powerSpec,
    List<List<double>> filterbank,
    bool logMel,
  ) {
    if (powerSpec.length != filterbank[0].length) {
      throw FilterbankShapeIncompatible();
    }

    return filterbank.map((filter) {
      double energy = 0.0;
      for (int i = 0; i < powerSpec.length; i++) {
        energy += powerSpec[i] * filter[i];
      }

      if (logMel) {
        return log10(energy + 1e-12).toDouble(); // log-mel
      } else {
        return energy;
      }
    }).toList();
  }
}
