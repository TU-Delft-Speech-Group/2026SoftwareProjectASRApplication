import 'dart:math';

import 'package:asr_application/services/audio/mel_service.dart';
import 'package:fftea/fftea.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final MelService service = MelService();
  final MelHelper helper = MelHelper();
  const epsilon = 1e-8;

  List<double> deterministicWindow(int length) {
    return List<double>.generate(length, (i) {
      final phase = i / length;
      return 0.5 * phase + (i.isEven ? 0.25 : -0.125);
    });
  }

  group('MelService', () {
    group('windowToMel', () {
      test('returns one log mel energy per configured mel filter', () {
        final melEnergies = service.windowToMel(
          deterministicWindow(service.nFft),
        );

        expect(melEnergies, hasLength(service.nMelEnergies));
      });

      test('returns very low log mel energies for a silent window', () {
        final melEnergies = service.windowToMel(
          List<double>.filled(service.nFft, 0.0),
        );

        expect(melEnergies, everyElement(lessThan(-4.0)));
      });

      test(
        'matches the explicit FFT, power spectrum, and filterbank pipeline',
        () {
          final window = deterministicWindow(service.nFft);
          final fft = FFT(service.nFft).realFft(window);
          final powerSpectrum = helper.powerSpectrum(fft);
          final filterbank = helper.generateFilterbank(
            service.fMin,
            service.fMax,
            service.nMelEnergies,
            service.nFft,
            service.sampleRate,
            false,
          );
          final melEnergies = helper.applyMelFilters(
            powerSpectrum,
            filterbank,
            false,
          );
          final expected = melEnergies.map((e) => log(e + 1e-10)).toList();

          final actual = service.windowToMel(window);

          expect(actual.length, expected.length);
          for (var i = 0; i < expected.length; i++) {
            expect(
              actual[i],
              closeTo(expected[i], epsilon),
              reason: 'Index $i',
            );
          }
        },
      );
    });
  });
}
