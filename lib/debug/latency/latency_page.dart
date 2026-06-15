import 'package:asr_application/services/pipeline/asr_runtime_instance.dart';
import 'package:flutter/material.dart';

import 'latency_result.dart';
import 'latency_runner.dart';

// Throwaway debug screen: measures transcription latency on-device.
// Reached from the speed icon on the home app bar. Safe to delete with the
// rest of lib/debug/latency and assets/latency.
class LatencyPage extends StatefulWidget {
  const LatencyPage({super.key, required this.runtime});

  final AsrRuntime runtime;

  @override
  State<LatencyPage> createState() => _LatencyPageState();
}

class _LatencyPageState extends State<LatencyPage> {
  bool _running = false;
  LiveLatencySession? _liveSession;
  LatencyResult? _result;
  String? _error;

  Future<void> _runBundled() async {
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await runBundledLatency(widget.runtime);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _startLive() async {
    setState(() {
      _error = null;
      _result = null;
    });
    final session = LiveLatencySession(widget.runtime);
    try {
      await session.start();
      if (mounted) setState(() => _liveSession = session);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _stopLive() async {
    final session = _liveSession;
    if (session == null) return;
    setState(() => _running = true);
    try {
      final result = await session.stop();
      if (mounted) {
        setState(() {
          _result = result;
          _liveSession = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = _liveSession != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Transcription latency')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            FilledButton.icon(
              onPressed: (_running || live) ? null : _runBundled,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run bundled sample (JFK 11s)'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _running
                  ? null
                  : (live ? _stopLive : _startLive),
              icon: Icon(live ? Icons.stop : Icons.mic),
              label: Text(live ? 'Stop live & measure' : 'Start live mic'),
            ),
            if (live)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Recording... speak, then tap stop.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 16),
            if (_running) const LinearProgressIndicator(),
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Error: $_error'),
                ),
              ),
            if (_result != null) _ResultCard(result: _result!),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final LatencyResult result;

  @override
  Widget build(BuildContext context) {
    String ms(num v) => '${v.toStringAsFixed(1)} ms';
    final r = result;
    final rows = <(String, String)>[
      ('Audio / duration', ms(r.audioMs)),
      ('Real-time factor (RTF)', r.rtf.toStringAsFixed(3)),
      ('First response', r.firstResponseMs == null ? 'n/a' : ms(r.firstResponseMs!)),
      ('Decode ticks', '${r.chunks}'),
      ('Per-tick avg', ms(r.avgChunkMs)),
      ('Per-tick p50', ms(r.p50)),
      ('Per-tick p90', ms(r.p90)),
      ('Per-tick max', ms(r.maxChunkMs)),
      ('Total processing', ms(r.totalProcessMs)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.label, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(k),
                    Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            const Divider(),
            const Text('Transcript:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(r.transcript.isEmpty ? '(empty)' : r.transcript),
          ],
        ),
      ),
    );
  }
}
