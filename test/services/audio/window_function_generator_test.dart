import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generator = WindowFunctionGenerator();
  const epsilon = 1e-8;

  void expectListClose(
    List<double> actual,
    List<double> expected,
    double epsilon,
  ) {
    expect(actual.length, expected.length);

    for (var i = 0; i < actual.length; i++) {
      expect(actual[i], closeTo(expected[i], epsilon));
    }
  }

  group('WindowFunctionGenerator', () {
    group('hamming', () {
      test('returns a window with the requested length', () {
        expect(generator.hamming(512), hasLength(512));
      });

      test('is symmetric and tapers at both ends', () {
        final window = generator.hamming(512);

        expect(window.first, closeTo(0.08, epsilon));
        expect(window.last, closeTo(0.08, epsilon));

        for (int i = 0; i < window.length; i++) {
          expect(window[i], closeTo(window[window.length - 1 - i], epsilon));
        }
      });

      test('equal values to python `Scipy.signal.windows.hamming(4)`', () {
        expectListClose(generator.hamming(4), [
          0.08,
          0.77,
          0.77,
          0.08,
        ], epsilon);
      });
      test('equal values to python `Scipy.signal.windows.hamming(8)`', () {
        expectListClose(generator.hamming(8), [
          0.08,
          0.25319469,
          0.64235963,
          0.95444568,
          0.95444568,
          0.64235963,
          0.25319469,
          0.08,
        ], epsilon);
      });
      test('equal values to python `Scipy.signal.windows.hamming(12)`', () {
        expectListClose(generator.hamming(12), [
          0.08,
          0.15302337,
          0.34890909,
          0.60546483,
          0.84123594,
          0.98136677,
          0.98136677,
          0.84123594,
          0.60546483,
          0.34890909,
          0.15302337,
          0.08,
        ], epsilon);
      });
      test('equal values to python `Scipy.signal.windows.hamming(16)`', () {
        expectListClose(generator.hamming(16), [
          0.08,
          0.11976909,
          0.23219992,
          0.39785218,
          0.58808309,
          0.77,
          0.91214782,
          0.9899479,
          0.9899479,
          0.91214782,
          0.77,
          0.58808309,
          0.39785218,
          0.23219992,
          0.11976909,
          0.08,
        ], epsilon);
      });
    });

    group('hann', () {
      test('returns a window with the requested length', () {
        expect(generator.hann(512), hasLength(512));
      });

      test('is symmetric and zero at both ends', () {
        final window = generator.hann(512);

        expect(window.first, closeTo(0.0, epsilon));
        expect(window.last, closeTo(0.0, epsilon));

        for (int i = 0; i < window.length; i++) {
          expect(window[i], closeTo(window[window.length - 1 - i], epsilon));
        }
      });

      test('equal values to python `Scipy.signal.windows.hann(4)`', () {
        expectListClose(generator.hann(4), [0.0, 0.75, 0.75, 0.0], epsilon);
      });
      test('equal values to python `Scipy.signal.windows.hann(8)`', () {
        expectListClose(generator.hann(8), [
          0.0,
          0.1882551,
          0.61126047,
          0.95048443,
          0.95048443,
          0.61126047,
          0.1882551,
          0.0,
        ], epsilon);
      });
      test('equal values to python `Scipy.signal.windows.hann(12)`', () {
        expectListClose(generator.hann(12), [
          0.0,
          0.07937323,
          0.29229249,
          0.57115742,
          0.82743037,
          0.97974649,
          0.97974649,
          0.82743037,
          0.57115742,
          0.29229249,
          0.07937323,
          0.0,
        ], epsilon);
      });
      test('equal values to python `Scipy.signal.windows.hann(16)`', () {
        expectListClose(generator.hann(16), [
          0.0,
          0.04322727,
          0.1654347,
          0.3454915,
          0.55226423,
          0.75,
          0.9045085,
          0.9890738,
          0.9890738,
          0.9045085,
          0.75,
          0.55226423,
          0.3454915,
          0.1654347,
          0.04322727,
          0.0,
        ], epsilon);
      });
    });
  });
}
