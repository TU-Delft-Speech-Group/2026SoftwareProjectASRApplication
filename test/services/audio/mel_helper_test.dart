import 'dart:typed_data';

import 'package:asr_application/exceptions/audio/filterbank_shape_incompatible.dart';
import 'package:asr_application/exceptions/audio/window_size_incompatible_with_target_fft.dart';
import 'package:asr_application/services/audio/mel_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  final MelHelper melHelper = MelHelper();
  const epsilon = 1e-8;

  group('MelHelper', () {
    group('log10', () {
      for (final (value, expected) in [
        (0.0001, -4.0),
        (0.5, -0.3010299956639812),
        (1.0, 0.0),
        (10.0, 1.0),
        (100.0, 2.0),
      ]) {
        test('log10 value is correct ($value -> $expected)', () {
          expect(melHelper.log10(value), closeTo(expected, epsilon));
        });
      }
    });

    group('Mel-Freq converters', () {
      /**
     * Randomly generated values from the Librosa library.
     * - 3x in range [0, 100]
     * - 3x in range [100, 1000]
     * - 3x in range [1000, 10_000]
     */
      for (final (freq, melSlaney, melHtk) in [
        (0.0, 0.0, 0.0),
        (18.748781090033184, 0.28123171635049776, 29.788215645921586),
        (51.215447982963525, 0.7682317197444528, 79.57949006701116),
        (80.7282912511051, 1.2109243687665765, 123.00787124246723),
        (175.66155443052128, 2.634923316457819, 252.33323951293346),
        (245.95956249223696, 3.689393437383554, 339.35990985084027),
        (670.1601223529526, 10.052401835294289, 756.8921706456182),
        (1735.2696648904057, 23.016706599402646, 1405.0602042043513),
        (2998.940169922923, 30.974262641014896, 1876.1311970283687),
        (7864.376626582389, 44.996944829019995, 2822.316077015542),
      ]) {
        test(
          'converts known Hz values to mel (slaney - $freq -> $melSlaney)',
          () {
            expect(
              melHelper.hzToMel(freq, htk: false),
              closeTo(melSlaney, epsilon),
            );
          },
        );

        test(
          'converts known mel values to Hz (slaney - $melSlaney -> $freq)',
          () {
            expect(
              melHelper.melToHz(melSlaney, htk: false),
              closeTo(freq, epsilon),
            );
          },
        );
        test('converts known Hz values to mel (htk - $freq -> $melHtk)', () {
          expect(melHelper.hzToMel(freq, htk: true), closeTo(melHtk, epsilon));
        });

        test('converts known mel values to Hz (htk - $melHtk -> $freq)', () {
          expect(melHelper.melToHz(melHtk, htk: true), closeTo(freq, epsilon));
        });
      }
    });

    group('Center padding', () {
      test('Overflow list gets error', () {
        expect(
          () => melHelper.centerPad(List.filled(6, 1.0), 5),
          throwsA(isA<WindowSizeIncompatibleWithTargetFft>()),
        );
      });
      test('Exact fit list get no padding', () {
        expect(
          melHelper.centerPad(List.filled(5, 1.0), 5),
          List.filled(5, 1.0),
        );
      });
      test('Underflow list get equally padded', () {
        expect(melHelper.centerPad(List.filled(2, 1.0), 5), [
          0.0,
          1.0,
          1.0,
          0.0,
          0.0,
        ]);
      });
    });

    group('Generate filterbank', () {
      test('matches the expected mel filterbank shape', () {
        final filterbank = melHelper.generateFilterbank(
          0,
          8_000,
          80,
          512,
          16_000,
          false,
        );

        expect(filterbank, hasLength(80));
        expect(filterbank.every((row) => row.length == 257), isTrue);
      });

      test(
        'matches the python `librosa.filters.mel(fmin=0, fmax=8000, n_mels=80, n_fft=512, sr=16_000, norm=slaney)` generated values',
        () async {
          final filterbank = melHelper.generateFilterbank(
            0,
            8_000,
            80,
            512,
            16_000,
            false,
          );

          final expected = await jsonToMatrix(
            'test/services/audio/golden/librosa_mel_filterbank_80x512_slaney.json',
          );
          expectMatrixClose(filterbank, expected, epsilon);
        },
      );

      test(
        'matches the python `librosa.filters.mel(fmin=0, fmax=8000, n_mels=80, n_fft=512, sr=16_000, htk=True)` generated values',
        () async {
          final filterbank = melHelper.generateFilterbank(
            0,
            8_000,
            80,
            512,
            16_000,
            true,
          );

          final expected = await jsonToMatrix(
            'test/services/audio/golden/librosa_mel_filterbank_80x512_htk.json',
          );
          expectMatrixClose(filterbank, expected, epsilon);
        },
      );
    });

    group('Power spectrum', () {
      test('returns squared magnitudes for the positive FFT bins', () {
        final frame = Float64x2List.fromList([
          Float64x2(3.0, 4.0),
          Float64x2(1.0, -2.0),
          Float64x2(0.0, -5.0),
          Float64x2(7.0, 8.0),
        ]);

        expect(melHelper.powerSpectrum(frame), [25.0, 5.0, 25.0]);
      });

      test('handles a single FFT bin', () {
        final frame = Float64x2List.fromList([Float64x2(-2.0, 3.0)]);

        expect(melHelper.powerSpectrum(frame), [13.0]);
      });
    });

    group('Apply Mel filters', () {
      test('applies each filter as a dot product', () {
        final melEnergies = melHelper.applyMelFilters(
          [2.0, 3.0, 5.0],
          [
            [1.0, 0.0, 0.5],
            [0.0, 2.0, 1.0],
          ],
          false,
        );

        expect(melEnergies, [4.5, 11.0]);
      });

      test('returns log10 energies when logMel is enabled', () {
        final melEnergies = melHelper.applyMelFilters(
          [2.0, 3.0, 5.0],
          [
            [1.0, 0.0, 0.5],
            [0.0, 2.0, 1.0],
          ],
          true,
        );

        expect(melEnergies[0], closeTo(melHelper.log10(4.5), epsilon));
        expect(melEnergies[1], closeTo(melHelper.log10(11.0), epsilon));
      });

      test('adds a small offset before logging zero-energy filters', () {
        final melEnergies = melHelper.applyMelFilters(
          [0.0, 0.0],
          [
            [1.0, 1.0],
          ],
          true,
        );

        expect(melEnergies, [closeTo(-12.0, epsilon)]);
      });

      test('throws when filterbank width differs from the power spectrum', () {
        expect(
          () => melHelper.applyMelFilters(
            [1.0, 2.0, 3.0],
            [
              [1.0, 1.0],
            ],
            false,
          ),
          throwsA(isA<FilterbankShapeIncompatible>()),
        );
      });
    });
  });
}
