import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'transformer_decoder_runner.dart';

/// ONNX adapter for an autoregressive transformer decoder.
///
/// Assumed session signature (positional, in the order the exporter declared):
///   inputs : [ tgt, encoder_out, cache_0, cache_1, ..., cache_{numLayers-1} ]
///   outputs: [ log_probs, new_cache_0, ..., new_cache_{numLayers-1} ]
///
/// `tgt` is the int64 prefix `[1, L]`. `log_probs` is the next-token
/// distribution `[1, vocab]` (last position only, not all prefix positions),
/// already log-softmaxed. The constructor validates that the session has the
/// expected number of inputs/outputs for the given `numLayers`.
class OrtTransformerDecoderRunner implements TransformerDecoderRunner {
  final OrtSession session;
  final OrtValue encoderOut;

  @override
  final int vocab;

  @override
  final int numLayers;

  final int decoderOutputSize;

  late final List<String> _inputNames = session.inputNames.cast<String>();
  late final List<String> _outputNames = session.outputNames.cast<String>();

  OrtTransformerDecoderRunner({
    required this.session,
    required this.encoderOut,
    required this.vocab,
    required this.numLayers,
    required this.decoderOutputSize,
  }) {
    if (vocab < 1) {
      throw ArgumentError('vocab must be >= 1 (got $vocab)');
    }
    if (numLayers < 1) {
      throw ArgumentError('numLayers must be >= 1 (got $numLayers)');
    }
    if (decoderOutputSize < 1) {
      throw ArgumentError(
        'decoderOutputSize must be >= 1 (got $decoderOutputSize)',
      );
    }
    final expectedInputs = 2 + numLayers;
    if (_inputNames.length != expectedInputs) {
      throw StateError(
        'session.inputNames has ${_inputNames.length} entries but expected '
        '$expectedInputs (tgt + encoder_out + $numLayers caches). '
        'Check that numLayers matches the exported decoder model.',
      );
    }
    final expectedOutputs = 1 + numLayers;
    if (_outputNames.length != expectedOutputs) {
      throw StateError(
        'session.outputNames has ${_outputNames.length} entries but expected '
        '$expectedOutputs (log_probs + $numLayers caches). '
        'Check that numLayers matches the exported decoder model.',
      );
    }
  }

  /// Convenience: build the decoder ONNX session with sensible per-platform
  /// defaults. CoreML EP is added on macOS / iOS. Drop it if you see
  /// `CoreMLExecutionProvider` fallback ping-pong in the logs.
  static Future<OrtSession> createSession(
    OnnxRuntime ort,
    String modelPath, {
    bool useCoreMl = true,
  }) async {
    final providers = (useCoreMl && (Platform.isMacOS || Platform.isIOS))
        ? const [OrtProvider.CORE_ML]
        : const <OrtProvider>[];
    return ort.createSession(
      modelPath,
      options: providers.isEmpty
          ? null
          : OrtSessionOptions(providers: providers),
    );
  }

  @override
  Future<List<Object>> initialCaches() async {
    final empty = Float32List(0);
    final caches = <Object>[];
    for (int i = 0; i < numLayers; i++) {
      caches.add(
        await OrtValue.fromList(empty, [1, 0, decoderOutputSize]),
      );
    }
    return caches;
  }

  @override
  Future<TransformerDecoderStep> step({
    required List<int> prefix,
    required List<Object> caches,
  }) async {
    final tgtTensor = await OrtValue.fromList(
      Int64List.fromList(prefix),
      [1, prefix.length],
    );

    final inputs = <String, OrtValue>{
      _inputNames[0]: tgtTensor,
      _inputNames[1]: encoderOut,
    };
    for (int i = 0; i < numLayers; i++) {
      inputs[_inputNames[i + 2]] = caches[i] as OrtValue;
    }

    final Map<String, OrtValue> outputs;
    try {
      outputs = await session.run(inputs);
    } finally {
      await tgtTensor.dispose();
    }

    final logProbsTensor = outputs[_outputNames[0]]!;
    final rawLogProbs = await logProbsTensor.asFlattenedList();
    await logProbsTensor.dispose();
    final logProbs = Float64List(rawLogProbs.length);
    for (int i = 0; i < rawLogProbs.length; i++) {
      logProbs[i] = (rawLogProbs[i] as num).toDouble();
    }

    final newCaches = <Object>[];
    for (int i = 0; i < numLayers; i++) {
      newCaches.add(outputs[_outputNames[i + 1]]! as Object);
    }

    return TransformerDecoderStep(logProbs: logProbs, caches: newCaches);
  }
}
