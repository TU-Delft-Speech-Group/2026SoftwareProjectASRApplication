# Pipeline overview

This document gives a high-level view of how data flows through the application, from microphone capture to text shown on screen. It is meant as a starting point for getting familiar with the codebase.

![Sequence diagram of the ASR pipeline: RecorderService captures audio and consults the Silero VAD, RecordingCoordinator drives the loop and feeds frames to StreamingTranscriptionService, which calls into the ASR engine's encoder/CTC/decoder and returns hypotheses for display.](pipeline-overview.svg)

The diagram source is in [`pipeline-overview.puml`](pipeline-overview.puml) (PlantUML); regenerate the SVG with any PlantUML renderer if the diagram changes.

## Stages

1. **Capture** : [`RecorderService`](../lib/services/audio/recorder_service.dart) reads raw audio and converts it to log-mel frames.
2. **Voice activity detection** : each frame is checked against the Silero VAD ([`SileroVadService`](../lib/services/audio/silero_vad_service.dart), behind the [`VadService`](../lib/services/audio/vad_service.dart) interface) to flag speech vs. silence.
3. **Coordination** : [`RecordingCoordinator`](../lib/ui/home/view_models/recording_coordinator.dart) drives the recording loop. Before the first speech is detected it calls `skipTo` to fast-forward the streaming service without transcribing; once speech starts, it forwards frames to the streaming service via `process`.
4. **Streaming transcription** : [`StreamingTranscriptionService`](../lib/services/engines/espnet/streaming/streaming_transcription_service.dart) buffers frames and calls into the active ASR engine to produce token hypotheses, tracking a confirmed prefix as more audio arrives.
5. **ASR engine** : [`EspnetAsrEngine`](../lib/services/engines/espnet/espnet_asr_engine.dart) runs the encoder and decodes with either joint CTC-attention (default) or CTC-only beam search, depending on whether the installed model bundle includes a decoder.
6. **Display** : `RecordingCoordinator` emits `RecordingEvent`s (`HypothesisUpdated`, `SegmentCommitted`, ...) that the UI renders. A segment closes (finalizing a transcript line) on encountering punctuation, hitting the buffer cap, or accumulating 5 seconds of silence.

See the [model packaging section in the README](../README.md#model-packaging) for how `.asrmodel` bundles determine which engine and decoding path are used.
