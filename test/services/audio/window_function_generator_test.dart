import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/utils/test_helpers.dart';

void main() {
  final generator = WindowFunctionGenerator();
  const epsilon = 1e-8;

  group('WindowFunctionGenerator', () {
    group('hamming', () {
      test('returns a window with the requested length', () {
        expect(generator.hamming(512), hasLength(512));
      });

      test('starts at the periodic edge value and mirrors around the peak', () {
        final window = generator.hamming(512);

        expect(window.first, closeTo(0.08, epsilon));

        for (int i = 1; i < window.length; i++) {
          expect(window[i], closeTo(window[window.length - i], epsilon));
        }
      });

      test(
        'equal values to python `scipy.signal.get_window("hamming", 4, fftbins=True)`',
        () {
          expectListClose(generator.hamming(4), [
            0.08,
            0.54,
            1.0,
            0.54,
          ], epsilon);
        },
      );
      test(
        'equal values to python `scipy.signal.get_window("hamming", 8, fftbins=True)`',
        () {
          expectListClose(generator.hamming(8), [
            0.08,
            0.21473088065418822,
            0.54,
            0.865269119345812,
            1.0,
            0.865269119345812,
            0.54,
            0.21473088065418822,
          ], epsilon);
        },
      );
      test(
        'equal values to python `scipy.signal.get_window("hamming", 12, fftbins=True)`',
        () {
          expectListClose(generator.hamming(12), [
            0.08,
            0.14162831425915828,
            0.31,
            0.54,
            0.77,
            0.9383716857408417,
            1.0,
            0.9383716857408417,
            0.77,
            0.54,
            0.31,
            0.14162831425915828,
          ], epsilon);
        },
      );
      test(
        'equal values to python `scipy.signal.get_window("hamming", 16, fftbins=True)`',
        () {
          expectListClose(generator.hamming(16), [
            0.08,
            0.11501541504480817,
            0.21473088065418822,
            0.36396562111205877,
            0.54,
            0.7160343788879413,
            0.865269119345812,
            0.9649845849551919,
            1.0,
            0.9649845849551919,
            0.865269119345812,
            0.7160343788879413,
            0.54,
            0.36396562111205877,
            0.21473088065418822,
            0.11501541504480817,
          ], epsilon);
        },
      );
    });

    group('hann', () {
      test('returns a window with the requested length', () {
        expect(generator.hann(512), hasLength(512));
      });

      test('starts at zero and mirrors around the peak', () {
        final window = generator.hann(512);

        expect(window.first, closeTo(0.0, epsilon));

        for (int i = 1; i < window.length; i++) {
          expect(window[i], closeTo(window[window.length - i], epsilon));
        }
      });

      test(
        'equal values to python `scipy.signal.get_window("hann", 4, fftbins=True)`',
        () {
          expectListClose(generator.hann(4), [0.0, 0.5, 1.0, 0.5], epsilon);
        },
      );
      test(
        'equal values to python `scipy.signal.get_window("hann", 8, fftbins=True)`',
        () {
          expectListClose(generator.hann(8), [
            0.0,
            0.14644660940672627,
            0.5,
            0.8535533905932737,
            1.0,
            0.8535533905932737,
            0.5,
            0.14644660940672627,
          ], epsilon);
        },
      );
      test(
        'equal values to python `scipy.signal.get_window("hann", 12, fftbins=True)`',
        () {
          expectListClose(generator.hann(12), [
            0.0,
            0.06698729810778065,
            0.25,
            0.5,
            0.75,
            0.9330127018922192,
            1.0,
            0.9330127018922192,
            0.75,
            0.5,
            0.25,
            0.06698729810778065,
          ], epsilon);
        },
      );
      test(
        'equal values to python `scipy.signal.get_window("hann", 16, fftbins=True)`',
        () {
          expectListClose(generator.hann(16), [
            0.0,
            0.03806023374435663,
            0.14644660940672627,
            0.30865828381745514,
            0.5,
            0.6913417161825449,
            0.8535533905932737,
            0.9619397662556434,
            1.0,
            0.9619397662556434,
            0.8535533905932737,
            0.6913417161825449,
            0.5,
            0.30865828381745514,
            0.14644660940672627,
            0.03806023374435663,
          ], epsilon);
        },
      );
    });
  });
}
