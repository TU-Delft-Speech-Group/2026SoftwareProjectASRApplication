import 'dart:io';

import 'package:asr_application/services/audio/windowing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/benchmark/corpus.dart';
import '../test/benchmark/runtime_loader.dart';
import '../test/benchmark/streaming_driver.dart';
import '../test/benchmark/wer.dart';

// English transcription accuracy benchmark.
//
// Streams every English corpus WAV through the live pipeline (bundled
// Gigaspeech model) and asserts the aggregate WER stays under the threshold.
// Runs as a Flutter integration test so the ONNX plugin is reachable:
//
//   RUN_BENCHMARK=1 flutter test integration_test/benchmark_test.dart -d macos
//
// Skipped unless RUN_BENCHMARK=1 so default test runs stay fast.
// BENCHMARK_LIMIT=N caps the run to N utterances for smoke-testing.
//
// Threshold is set above the observed bundled-M01 baseline (~0.66 WER on the
// DISC dysarthric corpus, joint CTC+attention). The CI job (a follow-up MR)
// recalibrates against the runner's measured baseline.
const _englishWerThreshold = 0.70;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('English benchmark: aggregate WER stays under threshold',
      timeout: const Timeout(Duration(minutes: 30)), () async {
    if (Platform.environment['RUN_BENCHMARK'] != '1') {
      markTestSkipped('set RUN_BENCHMARK=1 to run');
      return;
    }

    // Experiment knobs:
    //   ASRMODEL_PATH=/path/to/file.asrmodel  load a different .asrmodel
    //   DISABLE_LIVE_SILENCE=1                feed every chunk; no skip-on-silence
    //   ONE_SHOT=1                            single process() call, diagnostic only
    final runtime = await BenchmarkRuntime.load(
      packagePath: Platform.environment['ASRMODEL_PATH'],
    );
    final corpus = await Corpus.load();
    final wavTempDir = await Directory.systemTemp.createTemp('asr_bench_wavs_');
    final liveSilenceHandling =
        Platform.environment['DISABLE_LIVE_SILENCE'] != '1';
    final oneShot = Platform.environment['ONE_SHOT'] == '1';

    try {
      var entries = corpus.forLanguage('English');
      expect(entries, isNotEmpty, reason: 'No English corpus entries loaded');
      final limit = int.tryParse(Platform.environment['BENCHMARK_LIMIT'] ?? '');
      if (limit != null && limit > 0 && limit < entries.length) {
        entries = entries.take(limit).toList();
      }

      var totalSubs = 0;
      var totalIns = 0;
      var totalDels = 0;
      var totalRefWords = 0;
      final perUtterance = <_UtteranceReport>[];
      final tempWav = File('${wavTempDir.path}/utterance.wav');
      final overallStart = DateTime.now();

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final t0 = DateTime.now();
        await tempWav.writeAsBytes(await entry.loadWavBytes());
        runtime.runtime.streamingService.reset();
        final hypothesis = await transcribeWav(
          wavPath: tempWav.path,
          streaming: runtime.runtime.streamingService,
          windowing: WindowingService(),
          chunkDuration: const Duration(milliseconds: 500),
          liveSilenceHandling: liveSilenceHandling,
          oneShot: oneShot,
        );
        final dt = DateTime.now().difference(t0);
        final score = scoreTranscript(entry.groundTruth, hypothesis);
        totalSubs += score.substitutions;
        totalIns += score.insertions;
        totalDels += score.deletions;
        totalRefWords += score.referenceWords;
        perUtterance.add(_UtteranceReport(
          id: entry.id,
          truth: entry.groundTruth,
          hypothesis: hypothesis,
          wer: score.wer,
        ));
        // ignore: avoid_print
        print('[${i + 1}/${entries.length}] ${entry.id} '
            '(${dt.inMilliseconds}ms) WER=${score.wer.toStringAsFixed(3)} '
            'hyp="$hypothesis"');
      }

      // ignore: avoid_print
      print('Total time: ${DateTime.now().difference(overallStart).inSeconds}s');

      final totalErrors = totalSubs + totalIns + totalDels;
      final aggregateWer =
          totalRefWords == 0 ? 0.0 : totalErrors / totalRefWords;
      final perfect = perUtterance.where((r) => r.wer == 0.0).length;

      perUtterance.sort((a, b) => b.wer.compareTo(a.wer));
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('=== English benchmark summary ===');
      // ignore: avoid_print
      print('utterances:        ${entries.length}');
      // ignore: avoid_print
      print('reference words:   $totalRefWords');
      // ignore: avoid_print
      print('errors:            $totalErrors '
          '(subs $totalSubs, inserts $totalIns, deletes $totalDels)');
      // ignore: avoid_print
      print('aggregate WER:     ${aggregateWer.toStringAsFixed(3)} '
          '(threshold ${_englishWerThreshold.toStringAsFixed(3)})');
      // ignore: avoid_print
      print('perfect (WER=0):   $perfect / ${entries.length}');
      // ignore: avoid_print
      print('worst utterances:');
      for (final r in perUtterance.take(5)) {
        // ignore: avoid_print
        print('  ${r.id} WER=${r.wer.toStringAsFixed(3)}  '
            'truth="${r.truth}"  hyp="${r.hypothesis}"');
      }
      // ignore: avoid_print
      print('=================================');

      expect(
        aggregateWer,
        lessThanOrEqualTo(_englishWerThreshold),
        reason: 'English benchmark regressed: '
            'aggregate WER ${aggregateWer.toStringAsFixed(3)} exceeds '
            'threshold ${_englishWerThreshold.toStringAsFixed(3)}',
      );
    } finally {
      await runtime.dispose();
      if (await wavTempDir.exists()) {
        await wavTempDir.delete(recursive: true);
      }
    }
  });
}

class _UtteranceReport {
  const _UtteranceReport({
    required this.id,
    required this.truth,
    required this.hypothesis,
    required this.wer,
  });

  final String id;
  final String truth;
  final String hypothesis;
  final double wer;
}
