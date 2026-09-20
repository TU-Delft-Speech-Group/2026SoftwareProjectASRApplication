import 'package:flutter/foundation.dart';

import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_mel_service.dart';
import 'package:asr_application/services/engines/whisper/whisper_tokenizer.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';

/// Streaming transcription service for Whisper models.
///
/// All thresholds are configurable so the same service works across devices
/// without hardcoded assumptions about processing power.
class WhisperTranscriptionService implements AsrTranscriptionService {
  WhisperTranscriptionService({
    required this.pipeline,
    required this.tokenizer,
    required this.language,
    this.sampleRate = 16000,
    this.minInferenceSeconds = 0.5,
    this.maxBufferSeconds = 10.0,
    this.inferenceIntervalFrames = 10,
  });

  final WhisperAsrPipeline pipeline;
  final WhisperTokenizer tokenizer;
  final String language;
  final int sampleRate;
  final double minInferenceSeconds;
  final double maxBufferSeconds;
  final int inferenceIntervalFrames;

  int get _minSamples => (sampleRate * minInferenceSeconds).round();
  int get _maxSamples => (sampleRate * maxBufferSeconds).round();

  final WhisperMelService _melService = WhisperMelService();
  final List<double> _audioSamples = [];
  String _confirmedText = '';
  String _currentHypothesis = '';
  int _processedFrames = 0;
  int _framesSinceLastInference = 0;

  @override
  bool get needsRawAudio => true;

  @override
  String get confirmedText => _confirmedText;

  @override
  Future<StreamResult?> process(List<Float32List> allFrames) async {
    debugPrint('WHISPER-TR: process called, allFrames=\${allFrames.length}, buffer=\${_audioSamples.length}, processed=\$_processedFrames');

    if (allFrames.length > _processedFrames) {
      for (int i = _processedFrames; i < allFrames.length; i++) {
        for (final sample in allFrames[i]) {
          _audioSamples.add(sample.toDouble());
        }
      }
      _framesSinceLastInference += allFrames.length - _processedFrames;
      _processedFrames = allFrames.length;
    }

    // Keep only the most recent audio
    if (_audioSamples.length > _maxSamples) {
      _audioSamples.removeRange(0, _audioSamples.length - _maxSamples);
    }

    if (_audioSamples.length < _minSamples) return null;
    if (_framesSinceLastInference < inferenceIntervalFrames) return null;
    _framesSinceLastInference = 0;

    debugPrint('WHISPER-TR: enough audio, running inference...');

    try {
      final audio = Float64List.fromList(_audioSamples);
      final melFeatures = _melService.compute(audio);

      final forcedTokens = tokenizer.forcedDecoderIds(language);
      final tokenIds = await pipeline.greedyDecode(
        melFeatures: melFeatures,
        forcedTokens: forcedTokens,
      );

      _currentHypothesis = tokenizer.decode(tokenIds);

      debugPrint('WHISPER-TR: decoded: \$_currentHypothesis (\${tokenIds.length} tokens)');

      return OngoingResult(
        confirmedText: _confirmedText,
        hypothesis: _confirmedText + _currentHypothesis,
      );
    } catch (e) {
      debugPrint('WHISPER-TR ERROR: \$e');
      
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
