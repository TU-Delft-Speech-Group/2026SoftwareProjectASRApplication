# Developer Guide

This document explains the parts of the codebase that are easiest to get wrong
when extending the application. It focuses on architecture, model loading, the
live transcription path, and adding support for another model family.

The root [README](../README.md) covers project setup. The more detailed audio
sequence diagram is in [pipeline.md](pipeline.md).

The application has three main flows that meet in `lib/main.dart`:

```text
model package -> installed Model -> engine registry -> AsrRuntime

microphone -> audio frontend -> RecordingCoordinator
                                  -> AsrTranscriptionService
                                  -> transcription events

settings/widgets -> controllers and view models -> repositories/services
```

`main.dart` is the composition root. It creates concrete repositories,
services, engines, and controllers, then injects them into the UI. This is the
right place to register a new engine. It is not the right place for inference
logic, manifest parsing, or model-specific `if` statements.

The generic ASR layer is intentionally small. `AsrRuntimeController` manages
which runtime is active. `AsrRuntime` owns a loaded model and its resources.
`AsrTranscriptionService` is what the recording loop calls. The implementation
behind those contracts may be ESPnet today and something else later.

## How the application is wired

### Startup and model loading

Start with `lib/main.dart` when trying to understand the assembled application.
Startup creates local model storage, remote download support, the package
installer, the model repository, and persisted settings. It then refreshes the
installed model list and reconciles the saved model name with what is actually
on disk.

The engine registry is created with the engine implementations included in the
build:

```dart
final engineRegistry = AsrEngineRegistry(
  engines: const [EspnetAsrEngine()],
);
```

`AsrRuntimeController` receives a loader function. The loader asks
`ModelRepository` for the selected `Model`, then gives that model to the
registry:

```dart
Future<AsrRuntime> loadRuntime(String modelName) async {
  final result = await modelRepo.getModel(modelName);
  if (result is! Ok<Model>) {
    throw StateError('Model $modelName was not found.');
  }
  return engineRegistry.createRuntime(result.value);
}
```

This separation is important. `AsrRuntimeController` does not know about
ESPnet, manifests, files, or the registry. It only knows how to swap runtimes.
If a new model fails to load, it keeps the previous runtime alive. Once a new
runtime loads successfully, it disposes the old one.

`MainApp` listens to the runtime controller. A runtime change causes it to
replace `HomeViewModel` with one constructed from the new runtime's
`transcriptionService` and optional `vadService`. Deleting the final installed
model clears the runtime and puts the UI into its no-model state.

### Where responsibilities live

The easiest way to keep a feature readable is to put it at the same level as
the state it owns.

`lib/ui/` contains presentation and interaction. Widgets render values and
send commands. `HomeViewModel` owns the transcription entries and recording
state shown by the home page. `RecordingCoordinator` owns the live recording
state machine, but has no widget references.

`lib/services/` contains workflows and implementations. Model install, audio
capture, inference, token decoding, and engine code live here. A service should
not depend on a page or display a dialog.

`lib/data/repositories/` contains longer-lived application state and data
access. `SettingsRepository` is the source of truth for persisted settings;
`ModelRepository` is the source of truth for the current installed-model list.

`lib/domain/models/` contains values passed between those layers. Be careful
with the generic names in this directory: `ModelFiles` currently describes an
ESPnet package, even though `Model` itself is selected through a generic model
type.

## From microphone to text

The full diagram is in [pipeline-overview.svg](pipeline-overview.svg). The
important part is that feature extraction currently happens before the active
ASR engine receives data:

```text
AudioRecorder
  -> RecorderService
  -> WindowingService
  -> MelService
  -> RecordingCoordinator
  -> AsrTranscriptionService
```

### Audio frontend

`RecorderService` requests 16 kHz mono PCM16 audio. Automatic gain control,
echo cancellation, and noise suppression are disabled because platform voice
processing has previously reduced dysarthric speech to near-silence.

The service handles byte alignment, converts samples to the `-1..1` range,
runs voice activity detection, and appends feature frames from
`WindowingService`. VAD work is serialized so a new recorder chunk cannot
overtake inference on the previous one.

The current frontend is fixed to the parameters used by the ESPnet Conformer
models:

| Parameter | Current value |
| --- | --- |
| Sample rate | 16,000 Hz |
| Window | 400 samples, Hann |
| Hop | 160 samples, or 10 ms |
| FFT | 512 |
| Mel filters | 80, Slaney scale |
| Feature value | natural-log mel energy |

`SileroVadService` is normally created and initialized by the active engine.
If that initialization fails, the runtime exposes no VAD and
`RecorderService` falls back to a peak-amplitude threshold. The rest of the
recording pipeline works in either mode.

### RecordingCoordinator

`RecordingCoordinator` sits between audio capture and transcription. It wakes
every 500 ms and reads the complete frame list accumulated by
`RecorderService`.

Before speech begins, the coordinator does not send silence through the model.
It calls `skipTo` on the transcription service to advance its frame watermark.
`RecorderService.takeSpeechSinceLastCheck()` prevents a short burst of speech
between coordinator ticks from being lost just because the final audio chunk
was silent.

Once speech starts, the coordinator calls `process`. It translates the returned
result into events:

- `OngoingResult` becomes `HypothesisUpdated`.
- `SegmentResult` becomes `SegmentCommitted`.
- failures become `RecordingFailed` and stop the active loop.
- `DecodingStarted` and `DecodingFinished` drive the UI loading state.

A segment is also committed after five seconds of silence when confirmed text
exists. The coordinator keeps a locked confirmed prefix so a later unstable
hypothesis cannot make text disappear from the UI.

### The transcription contract

`AsrTranscriptionService` is the boundary a model implementation must satisfy:

```dart
abstract interface class AsrTranscriptionService {
  String get confirmedText;

  Future<StreamResult?> process(List<Float32List> allFrames);
  void skipTo(int frameCount);
  void commit();
  void reset();
}
```

There are a few non-obvious rules behind this interface.

`process` receives the entire accumulated frame list, not only the newest
chunk. The implementation keeps its own watermark and processes only frames it
has not seen. `skipTo` moves that watermark without transcription. `commit`
starts a new text segment but preserves the watermark. `reset` starts a new
recording and rewinds everything. Returning `null` means that the service
accepted the input but does not have a new result yet.

These rules let `RecordingCoordinator` remain engine-neutral. Do not add
ESPnet or future model checks to the coordinator; adapt the engine to this
contract, or deliberately replace the contract if it cannot represent the new
model's input.

## The current ESPnet engine

Everything under `lib/services/engines/espnet/` belongs to the current model
family. Generic code should not import its encoder, CTC, or decoder classes.

`EspnetAsrEngine` turns a repository `Model` into a loaded runtime. It reads
the model's vocabulary metadata, constructs the encoder and CTC services,
optionally constructs a transformer decoder, loads the vocabulary, and creates
Silero VAD. If construction fails halfway through, it disposes the resources
that were already opened.

`EspnetAsrPipeline` owns the encoder/CTC/decoder sequence. Its `encode` method
applies utterance mean and variance normalization, limits input to 1,500 frames,
runs the encoder and CTC layer, and creates a decoder runner when joint decoding
is available.

`StreamingTranscriptionService` turns repeated pipeline output into stable
text. It waits for at least 16 frames, keeps a frame watermark, and applies
local agreement to two consecutive hypotheses. It commits at punctuation or
before the model's usable context is exceeded. Errors are wrapped as
`PipelineStageException` with an `encode`, `decode`, or `tokenise` stage.

`EspnetAsrRuntime` owns the pipeline, transcription service, and VAD. Its
`dispose` method is the final owner cleanup called during model switches and app
shutdown.

The decoder is optional. A package without `decoder.onnx` uses CTC-only
decoding. CTC-only mode can also be forced for development with
`--dart-define=ASR_DECODER=ctc`.

## How models reach an engine

### Package installation

An `.asrmodel` is a ZIP archive with a custom extension. Users can pick one
from disk or download one from an allowed host. `ModelInstallController`
coordinates the UI workflow, while `ModelPackageService` performs the actual
install.

The installer extracts into a temporary directory, validates the manifest,
checks every declared SHA-256 hash, and copies the model into a staging
directory. It replaces an existing model by directory rename and keeps a backup
until the new directory is in place. Preserve that transaction when changing
installation code; a failed update should not destroy a working model.

Installed models live under:

```text
<application documents>/models/<model name>/
```

The manifest is preserved with the model so `ModelRepository` can rebuild the
domain `Model` after an app restart.

### Manifest and model type

The repository reads `model_type` from the preserved manifest. If the field is
missing, empty, or the manifest cannot be read, it falls back to `espnet` for
older packages.

A current ESPnet manifest looks like this:

```json
{
  "format_version": "2",
  "model_name": "DutchCGNConformerFBank_M01",
  "model_type": "espnet",
  "has_decoder": true,
  "vocab": {
    "blank_id": 0,
    "unk_id": 1,
    "sos_eos_id": 4999,
    "suppressed_ids": [0, 2, 3, 4],
    "word_boundary_marker": "\u2581"
  },
  "files": {
    "encoder.onnx": {"required": true, "sha256": "..."},
    "ctc.onnx": {"required": true, "sha256": "..."},
    "vocab.txt": {"required": true, "sha256": "..."},
    "decoder.onnx": {"required": false, "sha256": "..."}
  }
}
```

The installer accepts format versions `1` and `2`. Version `2` adds the
vocabulary IDs needed to decode models that do not follow the English
GigaSpeech token layout. Version `1` uses the built-in GigaSpeech defaults.

The existing Python packager in `scripts/export/` does not yet write
`model_type`; its packages load through the backward-compatible ESPnet
fallback. New package tooling should write the field explicitly.

### Registry dispatch

`AsrEngineRegistry` maps a model-type string to one `AsrEngine`. It rejects
duplicate registrations and throws `UnsupportedError` if an installed model
names a type that is not included in the build.

The registry solves runtime selection only. It does not make model files or the
audio frontend generic. That distinction matters when adding another model
family.

## Adding support for another model type

### First decide whether the input fits

If the new model consumes the existing 16 kHz, 80-bin log-mel frames and can
work incrementally with an accumulated frame list, the current
`AsrTranscriptionService` is a good boundary. Most of the work can stay inside
the new engine directory.

If it needs raw PCM, a different frontend, whole utterances, or a remote API,
do not disguise that difference inside `process(List<Float32List>)`. Move the
input boundary instead. A sensible direction is to pass typed PCM chunks with
timing to the runtime and let each engine own feature extraction. That is a
larger refactor, but it is much easier to maintain than treating incompatible
features as though they were the same.

### Make the installed model representation fit

Although runtime dispatch is generic, storage is still ESPnet-specific.
`ModelFiles`, `ModelPackageService`, `LocalModelService`,
`LocalModelStorageConfig`, and `ModelRepository` all assume these filenames:

```text
encoder.onnx
ctc.onnx
vocab.txt
decoder.onnx (optional)
```

For a model with a different artifact layout, change this layer before writing
the engine. The preferable long-term shape is a manifest-backed installed model
whose artifacts are not hard-coded into the generic domain type:

```dart
final class InstalledModel {
  const InstalledModel({
    required this.name,
    required this.modelType,
    required this.rootDirectory,
    required this.artifacts,
    required this.manifest,
  });

  final String name;
  final String modelType;
  final Directory rootDirectory;
  final Map<String, File> artifacts;
  final Map<String, dynamic> manifest;
}
```

In that design, package code verifies and preserves all declared files. The
selected engine decides which artifact names and metadata are required. This
avoids adding every future model filename to `ModelFiles` and every future
validation rule to a generic installer.

If a full storage refactor is too large for the first new engine, extending
`ModelFiles` can be a temporary step. Keep package validation, copying,
directory discovery, repository construction, and model tests in sync; changing
only one of them produces packages that install but cannot later be found or
loaded.

### Implement the engine and runtime

Add a stable string in `ModelType` and use the exact same value in manifests:

```dart
abstract final class ModelType {
  static const espnet = 'espnet';
  static const whisper = 'whisper';
}
```

Create the implementation under `lib/services/engines/<type>/`. The engine is
responsible for validating model-specific inputs and returning a fully
initialized runtime:

```dart
final class WhisperAsrEngine implements AsrEngine {
  const WhisperAsrEngine();

  @override
  String get modelType => ModelType.whisper;

  @override
  Future<AsrRuntime> createRuntime(Model model) async {
    // Validate artifacts and metadata, open model resources, and clean up
    // anything already opened if a later initialization step fails.
    return WhisperAsrRuntime(/* ... */);
  }
}
```

The runtime owns everything opened for that model. It exposes only the generic
transcription service and optional VAD to the rest of the app:

```dart
final class WhisperAsrRuntime implements AsrRuntime {
  WhisperAsrRuntime({
    required this.transcriptionService,
    this.vadService,
  });

  @override
  final AsrTranscriptionService transcriptionService;

  @override
  final VadService? vadService;

  @override
  Future<void> dispose() async {
    // Close sessions, streams, clients, tensors, and owned VAD resources.
  }
}
```

Keep model-specific pipeline methods inside the engine. `AsrPipeline` only
defines initialization and disposal because generic callers do not need to know
whether inference contains an encoder, CTC layer, decoder, or something else.

### Register it once

Add the engine to the registry in `main.dart`:

```dart
final engineRegistry = AsrEngineRegistry(
  engines: const [
    EspnetAsrEngine(),
    WhisperAsrEngine(),
  ],
);
```

Do not add model-type branches to `AsrRuntimeController`, `MainApp`,
`HomeViewModel`, `RecordingCoordinator`, or widgets. Those layers should keep
working through `AsrRuntime` and `AsrTranscriptionService`.

Also update the package generator so it writes `model_type` and the artifacts
required by the new engine. If the package format changes meaningfully, add a
new format version instead of changing the meaning of version `2`.

## Adding other application features

### Features with UI state

Widgets should remain the last step of a feature, not the place where its
workflow is implemented. Put mutable presentation state in a `ChangeNotifier`
view model or controller, inject it into the page, and let the widget render it.

The model-management path is a good example:

```text
SettingsModelList
  -> ModelInstallController
  -> ModelRepository / SettingsRepository
  -> LocalModelService / ModelPackageService
```

The widget knows how to display a model row. The controller knows what selecting
or deleting means. The repository owns the current list. The local service
knows how directories are changed. Keeping those jobs separate makes each part
testable and prevents storage details from leaking into navigation code.

For home-page behavior, `HomeViewModel` should own values displayed by the page,
while `RecordingCoordinator` should own timing and transcription state. A new
recording state belongs in the coordinator if it changes the audio loop; it
belongs in the view model if it only changes presentation.

### Persistent settings

`SettingsRepository` is the source of truth for locale, font size, split-screen
mode, and active model. A new setting should get a typed default, getter, and
setter there. The setter updates the in-memory map, writes through the injected
storage callback, and notifies listeners. Widgets read it through
`AppSettingsScope` rather than opening `SharedPreferences` themselves.

### Model-management features

Put user operations such as import, download, select, rename, and delete in
`ModelInstallController`. Put filesystem behavior in `LocalModelService` or
`ModelPackageService`. Put installed-model list state and domain construction
in `ModelRepository`.

This distinction is especially useful for errors. A checksum mismatch is a
package error. A duplicate directory name is a storage error. Choosing which
message/state the user sees is controller or UI work.

### Inference and native resources

New ONNX-backed code should use the contracts in
`lib/services/shared/onnx/` rather than calling `flutter_onnxruntime` throughout
business logic. Those wrappers make sessions and tensors replaceable in tests
and give resource ownership a clear home.

Native tensors and sessions are not released by Dart garbage collection in a
predictable way. Dispose temporary tensors in `finally` blocks, close sessions
from the owning runtime, and clean up partial initialization before rethrowing
an error. This is part of the engine contract in practice, even though Dart
cannot enforce it in the type system.
