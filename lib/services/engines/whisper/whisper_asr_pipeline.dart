import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'package:asr_application/services/pipeline/asr_pipeline_service.dart';
import 'package:asr_application/services/shared/onnx/onnx.dart';

/// Whisper encoder-decoder pipeline backed by ONNX Runtime (two files).
///
///   encoder.onnx  input_features [1, 80, 3000] -> hidden [1, 1500, d]
///   decoder.onnx  input_ids [1, T] + hidden    -> logits [1, T, vocab]
///
/// Used for packages without cross_kv.onnx. [WhisperKvAsrPipeline] is the
/// faster variant and is selected automatically when that file is present.
class WhisperAsrPipeline implements AsrPipeline {
  WhisperAsrPipeline({
    required this.encoderPath,
    required this.decoderPath,
    this.sessionOptions,
    OnnxInferenceBackendContract? backend,
  }) : _backend = backend ?? OnnxInferenceBackend();

  final String encoderPath;
  final String decoderPath;
  final OnnxInferenceBackendContract _backend;

  /// ONNX Runtime options for the encoder and decoder sessions. When null,
  /// they are built from the build flags ORT_THREADS (0 = ORT default) and
  /// ORT_XNNPACK (true/false), so settings can be compared without code edits.
  final OrtSessionOptions? sessionOptions;

  static const int _envThreads = int.fromEnvironment('ORT_THREADS');
  static const bool _envXnnpack = bool.fromEnvironment('ORT_XNNPACK');

  static OrtSessionOptions? _optionsFromEnvironment() {
    if (_envThreads <= 0 && !_envXnnpack) return null;
    return OrtSessionOptions(
      intraOpNumThreads: _envThreads > 0 ? _envThreads : null,
      providers: _envXnnpack ? const [OrtProvider.XNNPACK, OrtProvider.CPU] : null,
    );
  }

  OnnxInferenceSessionContract? _encoderSession;
  OnnxInferenceSessionContract? _decoderSession;

  @override
  bool get isInitialized => _encoderSession != null && _decoderSession != null;

  @override
  Future<void> initialize() async {
    if (isInitialized) return;

    dev.log('Loading Whisper encoder: $encoderPath', name: 'WhisperPipeline');
    final options = sessionOptions ?? _optionsFromEnvironment();
    dev.log(
      'Session options: threads=${_envThreads > 0 ? _envThreads : "default"} '
      'xnnpack=$_envXnnpack custom=${sessionOptions != null}',
      name: 'WhisperPipeline',
    );
    _encoderSession = await _backend.createSessionFromFile(encoderPath, options: options);

    dev.log('Loading Whisper decoder: $decoderPath', name: 'WhisperPipeline');
    _decoderSession = await _backend.createSessionFromFile(decoderPath, options: options);

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

      // Output name depends on the exporter; fall back to the first output.
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
      // Drop any extra outputs (e.g. present.* caches); this pipeline re-runs
      // the full sequence each step. See WhisperKvAsrPipeline for caching.
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

  /// Full greedy decoding: encode once, then re-run the decoder on the whole
  /// token sequence for each new token. Returns the generated tokens (the
  /// forced prefix is not included; EOS is, when reached).
  Future<List<int>> greedyDecode({
    required Float32List melFeatures,
    required List<int> forcedTokens,
    int maxTokens = 224,
    int eosToken = 50257,
  }) async {
    final watch = Stopwatch()..start();
    final encoderOut = await encode(melFeatures);
    final encMs = watch.elapsedMilliseconds;

    try {
      final tokenIds = List<int>.from(forcedTokens);
      for (int step = 0; step < maxTokens; step++) {
        final logits = await decodeStep(Int64List.fromList(tokenIds), encoderOut);
        final Float32List lastRow;
        try {
          // logits are [1, seq_len, vocab]; only the last position is needed.
          final vocab = logits.shape.last;
          final all = await logits.asFloat32List();
          lastRow = Float32List.sublistView(all, all.length - vocab);
        } finally {
          await logits.dispose();
        }

        final best = argmaxNoRepeatTrigram(lastRow, tokenIds);
        tokenIds.add(best);
        if (best == eosToken) break;
      }
      debugPrint('WHISPER: encoder ${encMs}ms | decode '
          '${watch.elapsedMilliseconds - encMs}ms | '
          '${tokenIds.length - forcedTokens.length} tokens');
      return tokenIds.sublist(forcedTokens.length);
    } finally {
      await encoderOut.dispose();
    }
  }

  /// Greedy argmax over [logits] (shape [vocab]) that skips any token which
  /// would repeat a trigram already in [seq]. Same rule as
  /// experiments/eval_m01.py with --ngram 3, so app and evaluation decode
  /// identically.
  static int argmaxNoRepeatTrigram(Float32List logits, List<int> seq) {
    final banned = <int>{};
    if (seq.length >= 2) {
      final p0 = seq[seq.length - 2];
      final p1 = seq[seq.length - 1];
      for (int i = 0; i < seq.length - 2; i++) {
        if (seq[i] == p0 && seq[i + 1] == p1) banned.add(seq[i + 2]);
      }
    }
    int best = -1;
    double bestScore = double.negativeInfinity;
    for (int v = 0; v < logits.length; v++) {
      if (logits[v] > bestScore && !banned.contains(v)) {
        bestScore = logits[v];
        best = v;
      }
    }
    return best;
  }

  @override
  Future<void> dispose() async {
    await _encoderSession?.close();
    await _decoderSession?.close();
    _encoderSession = null;
    _decoderSession = null;
  }
}

/// Whisper pipeline with a KV-cache decoder (three ONNX files).
///
///   encoder.onnx   input_features [1, 80, 3000] -> hidden [1, 1500, d]
///   cross_kv.onnx  encoder_hidden_states -> cross_k, cross_v [L, 1, H, 1500, Dh]
///                  (run once per clip)
///   decoder.onnx   decoder_step: token [1, 1], pos [1], self_k / self_v
///                  [L, 1, H, T, Dh], cross_k, cross_v
///                  -> logits [1, V], new_self_k / new_self_v [L, 1, H, T+1, Dh]
///                  (run once per token)
///
/// Compared with [WhisperAsrPipeline], each step feeds one token instead of
/// the whole sequence and copies only [1, V] logits back to Dart instead of
/// [1, seq_len, V]. Slot 0 of the self-attention cache is a masked dummy, so
/// decoding starts from zero tensors of length 1
/// (see experiments/export_kv_decoder.py).
class WhisperKvAsrPipeline extends WhisperAsrPipeline {
  WhisperKvAsrPipeline({
    required super.encoderPath,
    required String decoderStepPath,
    required this.crossKvPath,
    super.sessionOptions,
    super.backend,
  }) : super(decoderPath: decoderStepPath);

  final String crossKvPath;
  OnnxInferenceSessionContract? _crossSession;

  @override
  bool get isInitialized => super.isInitialized && _crossSession != null;

  @override
  Future<void> initialize() async {
    if (isInitialized) return;
    if (!super.isInitialized) {
      await super.initialize(); // encoder + decoder_step sessions
    }
    dev.log('Loading Whisper cross-KV: $crossKvPath', name: 'WhisperPipeline');
    final options = sessionOptions ?? WhisperAsrPipeline._optionsFromEnvironment();
    _crossSession = await _backend.createSessionFromFile(crossKvPath, options: options);
    dev.log('KV-cache decoder enabled', name: 'WhisperPipeline');
  }

  @override
  Future<List<int>> greedyDecode({
    required Float32List melFeatures,
    required List<int> forcedTokens,
    int maxTokens = 224,
    int eosToken = 50257,
  }) async {
    assert(isInitialized, 'Pipeline not initialized');
    final watch = Stopwatch()..start();
    final enc = await encode(melFeatures);
    OnnxTensorContract? encoderOut = enc;
    final encMs = watch.elapsedMilliseconds;

    OnnxTensorContract? crossK;
    OnnxTensorContract? crossV;
    OnnxTensorContract? selfK;
    OnnxTensorContract? selfV;

    try {
      // 1. cross-attention keys/values, once per clip
      final cross = await _crossSession!.run({'encoder_hidden_states': enc});
      crossK = cross['cross_k'];
      crossV = cross['cross_v'];
      if (crossK == null || crossV == null) {
        throw StateError('cross_kv.onnx must output cross_k and cross_v, got ${cross.keys}');
      }
      await enc.dispose();
      encoderOut = null;
      final crossMs = watch.elapsedMilliseconds - encMs;

      // 2. empty self-attention cache [L, 1, H, 1, Dh] (dummy slot 0)
      final s = crossK.shape;
      final cacheShape = [s[0], 1, s[2], 1, s[4]];
      final cacheSize = s[0] * s[2] * s[4];
      selfK = await _backend.createTensor(Float32List(cacheSize), cacheShape);
      selfV = await _backend.createTensor(Float32List(cacheSize), cacheShape);

      // One decoder step. Replaces the cache tensors with the new ones and
      // returns the logits only when they are needed.
      Future<Float32List?> feed(int token, int pos, {required bool wantLogits}) async {
        final tokT = await _backend.createTensor(Int64List.fromList([token]), [1, 1]);
        final posT = await _backend.createTensor(Int64List.fromList([pos]), [1]);
        try {
          final out = await _decoderSession!.run({
            'token': tokT,
            'pos': posT,
            'self_k': selfK!,
            'self_v': selfV!,
            'cross_k': crossK!,
            'cross_v': crossV!,
          });
          final logitsT = out['logits'];
          final newK = out['new_self_k'];
          final newV = out['new_self_v'];
          if (logitsT == null || newK == null || newV == null) {
            for (final t in out.values) {
              await t.dispose();
            }
            throw StateError('decoder_step must output logits, new_self_k, new_self_v, got ${out.keys}');
          }
          final logits = wantLogits ? await logitsT.asFloat32List() : null;
          await logitsT.dispose();
          await selfK!.dispose();
          await selfV!.dispose();
          selfK = newK;
          selfV = newV;
          return logits;
        } finally {
          await tokT.dispose();
          await posT.dispose();
        }
      }

      // 3. forced prefix (only the last step's logits are used)
      Float32List? logits;
      for (int i = 0; i < forcedTokens.length; i++) {
        logits = await feed(forcedTokens[i], i, wantLogits: i == forcedTokens.length - 1);
      }

      // 4. greedy loop, one token per step
      final seq = List<int>.from(forcedTokens);
      final generated = <int>[];
      final loopWatch = Stopwatch()..start();
      for (int step = 0; step < maxTokens; step++) {
        final best = WhisperAsrPipeline.argmaxNoRepeatTrigram(logits!, seq);
        seq.add(best);
        generated.add(best);
        if (best == eosToken) break;
        logits = await feed(best, seq.length - 1, wantLogits: true);
      }
      final perToken = generated.isEmpty ? 0 : loopWatch.elapsedMilliseconds / generated.length;
      debugPrint('WHISPER-KV: encoder ${encMs}ms | cross_kv ${crossMs}ms | '
          '${generated.length} tokens, ${perToken.toStringAsFixed(1)} ms/token');
      return generated;
    } finally {
      await encoderOut?.dispose();
      await crossK?.dispose();
      await crossV?.dispose();
      await selfK?.dispose();
      await selfV?.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    await _crossSession?.close();
    _crossSession = null;
    await super.dispose();
  }
}
