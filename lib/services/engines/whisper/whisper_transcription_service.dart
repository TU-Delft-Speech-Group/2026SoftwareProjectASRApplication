import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_mel_service.dart';
import 'package:asr_application/services/engines/whisper/whisper_tokenizer.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';

/// Streaming transcription service for Whisper models.
///
/// Accumulates audio frames and runs the full encoder-decoder pipeline
/// when enough audio has accumulated. Uses a simple re-encode-all strategy
/// (no incremental KV-cache) suitable for whisper-tiny on mobile.
class WhisperTranscriptionService implements AsrTranscriptionService {
  WhisperTranscriptionService({
    required this.pipeline,
    required this.tokenizer,
    required this.language,
  });

  final WhisperAsrPipeline pipeline;
  final WhisperTokenizer tokenizer;
  final String language;

  final WhisperMelService _melService = WhisperMelService();
  final List<double> _audioSamples = [];
  String _confirmedText = '';
  String _currentHypothesis = '';
  int _processedFrames = 0;

  /// Minimum audio length (in samples) before running inference.
  /// 0.5 seconds at 16kHz = 8000 samples.
  static const int _minSamplesForInference = 8000;

  /// How often to re-run inference (in new frames received).
  static const int _inferenceInterval = 10;
  int _framesSinceLastInference = 0;

  @override
  @override
  bool get needsRawAudio => true;

  @override
  String get confirmedText => _confirmedText;

  @override
  Future<StreamResult?> process(List<Float32List> allFrames) async {
    debugPrint('WHISPER-TR: process called, allFrames=${allFrames.length}, buffer=${_audioSamples.length}, processed=$_processedFrames');
    // Collect new audio frames.
    if (allFrames.length > _processedFrames) {
      for (int i = _processedFrames; i < allFrames.length; i++) {
        for (final sample in allFrames[i]) {
          _audioSamples.add(sample.toDouble());
        }
      }
      _framesSinceLastInference += allFrames.length - _processedFrames;
      _processedFrames = allFrames.length;
    }

    // Only run inference if we have enough audio and enough new frames.
    if (_audioSamples.length < _minSamplesForInference) return null;
    debugPrint('WHISPER-TR: enough audio, running inference...');
    if (_framesSinceLastInference < _inferenceInterval) return null;
    _framesSinceLastInference = 0;

    try {
      // Convert audio to mel spectrogram.
      final audio = Float64List.fromList(_audioSamples);
      final melFeatures = _melService.compute(audio);

      // Run greedy decoding.
      final forcedTokens = tokenizer.forcedDecoderIds(language);
      final tokenIds = await pipeline.greedyDecode(
        melFeatures: melFeatures,
        forcedTokens: forcedTokens,
      );

      // Decode tokens to text.
      _currentHypothesis = tokenizer.decode(tokenIds);
    debugPrint('WHISPER-TR: decoded: $_currentHypothesis (${tokenIds.length} tokens)');

      dev.log(
        'Whisper decoded: \$_currentHypothesis '
        '(\${tokenIds.length} tokens, '
        '\${(_audioSamples.length / 16000).toStringAsFixed(1)}s audio)',
        name: 'WhisperTranscription',
      );

      return OngoingResult(
        confirmedText: _confirmedText,
        hypothesis: _confirmedText + _currentHypothesis,
      );
    } catch (e, st) {
      dev.log(
        'Whisper inference error: \$e',
        name: 'WhisperTranscription',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  void commit() {
    _confirmedText += _currentHypothesis;
    _currentHypothesis = '';
    _audioSamples.clear();
    _processedFrames = 0;
    _framesSinceLastInference = 0;
  }

  @override
  void reset() {
    _confirmedText = '';
    _currentHypothesis = '';
    _audioSamples.clear();
    _processedFrames = 0;
    _framesSinceLastInference = 0;
  }

  @override
  void skipTo(int frameCount) {
    _processedFrames = frameCount;
  }
}
