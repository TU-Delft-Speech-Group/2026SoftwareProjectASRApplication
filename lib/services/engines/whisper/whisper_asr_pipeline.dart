import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';
import 'package:asr_application/services/shared/onnx/onnx.dart';

/// Whisper encoder-decoder pipeline backed by ONNX Runtime.
///
/// The encoder takes mel spectrogram features [1, 80, 3000] and produces
/// hidden states [1, 1500, dim]. The decoder takes token ids + encoder output
/// and autoregressively produces logits over the vocabulary.
class WhisperAsrPipeline implements AsrPipeline {
  WhisperAsrPipeline({
    required this.encoderPath,
    required this.decoderPath,
    OnnxInferenceBackendContract? backend,
  }) : _backend = backend ?? OnnxInferenceBackend();

  final String encoderPath;
  final String decoderPath;
  final OnnxInferenceBackendContract _backend;

  OnnxInferenceSessionContract? _encoderSession;
  OnnxInferenceSessionContract? _decoderSession;

  @override
  bool get isInitialized => _encoderSession != null && _decoderSession != null;

  @override
  Future<void> initialize() async {
    if (isInitialized) return;

    dev.log('Loading Whisper encoder: $encoderPath', name: 'WhisperPipeline');
    _encoderSession = await _backend.createSessionFromFile(encoderPath);

    dev.log('Loading Whisper decoder: $decoderPath', name: 'WhisperPipeline');
    _decoderSession = await _backend.createSessionFromFile(decoderPath);

    dev.log('Whisper pipeline initialized', name: 'WhisperPipeline');
  }

  /// Runs the encoder on mel spectrogram features.
  ///
  /// [melFeatures] shape: [1, 80, 3000] (30 seconds of audio at 16kHz).
  /// Returns encoder hidden states shape: [1, 1500, dim].
  Future<OnnxTensorContract> encode(Float32List melFeatures) async {
    assert(isInitialized, 'Pipeline not initialized');

    final inputTensor = await _backend.createTensor(
      melFeatures,
      [1, 80, 3000],
    );

    try {
      final outputs = await _encoderSession!.run({
        'input_features': inputTensor,
      });

      // The encoder output key varies by export: "last_hidden_state" or
      // "encoder_hidden_states". Try both.
      final encOut = outputs['last_hidden_state'] ?? outputs.values.first;
      dev.log(
        'Encoder output shape: ${encOut.shape}',
        name: 'WhisperPipeline',
      );

      // Dispose input but NOT output (caller needs it for decoder).
      await inputTensor.dispose();
      // Dispose any other outputs we don't need.
      for (final entry in outputs.entries) {
        if (!identical(entry.value, encOut)) {
          await entry.value.dispose();
        }
      }

      return encOut;
    } catch (e) {
      await inputTensor.dispose();
      rethrow;
    }
  }

  /// Runs one decoder step: given token ids and encoder hidden states,
  /// returns logits over the vocabulary.
  ///
  /// [tokenIds] shape: [1, seq_len] (Int64 token ids).
  /// [encoderOut] shape: [1, 1500, dim] (from [encode]).
  /// Returns logits shape: [1, seq_len, vocab_size].
  Future<OnnxTensorContract> decodeStep(
    Int64List tokenIds,
    OnnxTensorContract encoderOut,
  ) async {
    assert(isInitialized, 'Pipeline not initialized');

    final idsTensor = await _backend.createTensor(
      tokenIds,
      [1, tokenIds.length],
    );

    try {
      final outputs = await _decoderSession!.run({
        'input_ids': idsTensor,
        'encoder_hidden_states': encoderOut,
      });

      final logits = outputs['logits'] ?? outputs.values.first;

      await idsTensor.dispose();
      // Dispose KV-cache outputs (present.*) — we re-run full sequence each
      // step for simplicity. KV-cache optimization comes later.
      for (final entry in outputs.entries) {
        if (!identical(entry.value, logits)) {
          await entry.value.dispose();
        }
      }

      return logits;
    } catch (e) {
      await idsTensor.dispose();
      rethrow;
    }
  }

  /// Runs full greedy decoding: encode mel, then autoregressively decode.
  ///
  /// Returns a list of token ids (excluding the forced prefix).
  Future<List<int>> greedyDecode({
    required Float32List melFeatures,
    required List<int> forcedTokens,
    int maxTokens = 224,
    int eosToken = 50257,
  }) async {
    final encoderOut = await encode(melFeatures);

    try {
      final tokenIds = List<int>.from(forcedTokens);

      for (int step = 0; step < maxTokens; step++) {
        final inputIds = Int64List.fromList(tokenIds);
        final logits = await decodeStep(inputIds, encoderOut);

        // Get logits for the last position.
        final allLogits = await logits.asFloat32List();
        final vocabSize = 51865;
        final lastPos = tokenIds.length - 1;
        final offset = lastPos * vocabSize;

        // No-repeat 3-gram suppression: if the last 2 tokens plus a
        // candidate would form a trigram already seen, block that candidate.
        final banned = <int>{};
        if (tokenIds.length >= 2) {
          final prev0 = tokenIds[tokenIds.length - 2];
          final prev1 = tokenIds[tokenIds.length - 1];
          for (int i = 0; i < tokenIds.length - 2; i++) {
            if (tokenIds[i] == prev0 && tokenIds[i + 1] == prev1) {
              banned.add(tokenIds[i + 2]);
            }
          }
        }

        // Greedy: argmax over vocabulary, skipping banned tokens.
        int bestToken = -1;
        double bestScore = double.negativeInfinity;
        for (int v = 0; v < vocabSize; v++) {
          if (banned.contains(v)) continue;
          if (allLogits[offset + v] > bestScore) {
            bestScore = allLogits[offset + v];
            bestToken = v;
          }
        }

        await logits.dispose();
        tokenIds.add(bestToken);

        if (bestToken == eosToken) break;
      }

      // Return only the generated tokens (after forced prefix).
      return tokenIds.sublist(forcedTokens.length);
    } finally {
      await encoderOut.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    await _encoderSession?.close();
    await _decoderSession?.close();
    _encoderSession = null;
    _decoderSession = null;
  }
}
