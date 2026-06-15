@Tags(['benchmark'])
library;

import 'dart:io';
import 'dart:math';

import 'package:asr_application/debug/latency/latency_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/benchmark/runtime_loader.dart';

// Throwaway: verifies the bundled latency path and reports an aggregate desktop
// estimate over N runs. Relates to #220. Run with:
//   RUN_BENCHMARK=1 ASRMODEL_PATH=<...>.asrmodel LATENCY_RUNS=10 \
//     flutter test integration_test/latency_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('bundled latency aggregate', timeout: const Timeout(Duration(minutes: 30)), () async {
    if (Platform.environment['RUN_BENCHMARK'] != '1') {
      markTestSkipped('set RUN_BENCHMARK=1 to run');
      return;
    }
    final runs = int.tryParse(Platform.environment['LATENCY_RUNS'] ?? '') ?? 10;
    final runtime = await BenchmarkRuntime.load(
      packagePath: Platform.environment['ASRMODEL_PATH'],
    );

    final rtf = <double>[];
    final firstResponse = <double>[];
    final perTickAvg = <double>[];
    final perTickP90 = <double>[];
    try {
      for (var i = 0; i < runs; i++) {
        final r = await runBundledLatency(runtime.runtime);
        rtf.add(r.rtf);
        if (r.firstResponseMs != null) firstResponse.add(r.firstResponseMs!.toDouble());
        perTickAvg.add(r.avgChunkMs);
        perTickP90.add(r.p90);
        // ignore: avoid_print
        print('run ${i + 1}/$runs  RTF=${r.rtf.toStringAsFixed(3)}  '
            'firstResp=${r.firstResponseMs}ms  avg=${r.avgChunkMs.toStringAsFixed(1)}  '
            'p90=${r.p90.toStringAsFixed(1)}ms');
      }
    } finally {
      await runtime.dispose();
    }

    // Run 1 is a cold start (ONNX warmup); report steady-state separately.
    String stat(List<double> xs) {
      final s = [...xs]..sort();
      final mean = s.reduce((a, b) => a + b) / s.length;
      final variance =
          s.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / s.length;
      return 'mean=${mean.toStringAsFixed(2)} sd=${sqrt(variance).toStringAsFixed(2)} '
          'min=${s.first.toStringAsFixed(2)} max=${s.last.toStringAsFixed(2)}';
    }

    List<double> warm(List<double> xs) => xs.length > 1 ? xs.sublist(1) : xs;

    // ignore: avoid_print
    print('\n=== AGGREGATE over $runs runs (cold=run1, warm=runs 2..$runs) ===');
    // ignore: avoid_print
    print('RTF            all:  ${stat(rtf)}');
    // ignore: avoid_print
    print('RTF            warm: ${stat(warm(rtf))}');
    // ignore: avoid_print
    print('first-resp ms  warm: ${stat(warm(firstResponse))}');
    // ignore: avoid_print
    print('per-tick avg   warm: ${stat(warm(perTickAvg))}');
    // ignore: avoid_print
    print('per-tick p90   warm: ${stat(warm(perTickP90))}');

    expect(rtf.length, runs);
  });
}
