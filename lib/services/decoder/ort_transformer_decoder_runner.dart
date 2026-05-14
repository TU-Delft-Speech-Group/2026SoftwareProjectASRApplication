import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'transformer_decoder_runner.dart';

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
    this.numLayers = 6,
    this.decoderOutputSize = 256,
  });

  /// Convenience: build the decoder ONNX session with sensible per-platform
  /// defaults. CoreML EP is added on macOS / iOS — drop it if you see
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

    final outputs = await session.run(inputs);

    final rawLogProbs = await outputs[_outputNames[0]]!.asFlattenedList();
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
