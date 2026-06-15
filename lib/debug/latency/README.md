# Transcription latency measurement (throwaway)

A debug-only feature to measure on-device transcription latency. Delete
`lib/debug/latency/`, `assets/latency/`, `integration_test/latency_test.dart`,
the `assets/latency/...` line in `pubspec.yaml`, and the `latencyRuntime` wiring
in `home_page.dart` / `main.dart` to remove it.

## How to use (Android handoff)

1. Build/install the app from the `latency-measurement` branch on the phone.
2. **Install a model first** (Settings → add model). The latency button only
   appears once a model is loaded, and the bundled sample is English so use the
   English Gigaspeech model.
3. On the home screen, tap the **speedometer icon** in the app bar.
4. Tap **Run bundled sample** (deterministic, comparable across phones) and/or
   **Start live mic** → speak → **Stop**.
5. Screenshot / record the numbers shown.

## Metrics

- **RTF** (real-time factor): processing time / audio duration. `< 1` = faster
  than real-time (keeps up with a live stream).
- **First response**: wall-clock from start to the first non-empty hypothesis.
- **Per-tick** avg / p50 / p90 / max: encode + decode time per streaming tick.

## Audio

`assets/latency/jfk_sample.wav` is a public-domain clip (JFK inaugural address,
US government work) from the whisper.cpp samples, 16 kHz mono PCM. It is **not**
the project's speaker corpus.

## Desktop baseline (Windows x64, M01Libri100)

RTF 0.91, first-response ~200 ms, per-tick avg ~456 ms / p90 ~694 ms.
Run it yourself with:

```
RUN_BENCHMARK=1 ASRMODEL_PATH=<...>.asrmodel \
  flutter test integration_test/latency_test.dart -d windows
```
