import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:asr_application/services/engines/whisper/whisper_asr_pipeline.dart';
import 'package:asr_application/services/engines/whisper/whisper_mel_service.dart';
import 'package:asr_application/services/engines/whisper/whisper_tokenizer.dart';
import 'package:asr_application/services/pipeline/asr_transcription_service.dart';

class WhisperTranscriptionService implements AsrTranscriptionService {
  WhisperTranscriptionService({
    required this.pipeline,
    required this.tokenizer,
    required this.language,
    this.sampleRate = 16000,
    this.minInferenceSeconds = 1.0,
    this.maxBufferSeconds = 10.0,
    this.minSecondsBetweenInference = 1.0,
    this.debugAudioDir,
    WhisperMelService? melService,
  }) : _melService = melService ?? WhisperMelService();

  final WhisperAsrPipeline pipeline;
  final WhisperTokenizer tokenizer;
  final String language;
  final int sampleRate;
  final double minInferenceSeconds;
  final double maxBufferSeconds;
  final double minSecondsBetweenInference;
  final WhisperMelService _melService;
  final String? debugAudioDir;

  int get _minSamples => (sampleRate * minInferenceSeconds).round();
  int get _maxSamples => (sampleRate * maxBufferSeconds).round();

  String _confirmedText = '';
  String _currentHypothesis = '';
  int _lastInferenceLength = 0;
  bool _inferenceRunning = false;
  int _saveCounter = 0;

  @override
  bool get needsRawAudio => true;

  @override
  String get confirmedText => _confirmedText;

  @override
  Future<StreamResult?> process(List<Float32List> allFrames) async {
    if (allFrames.isEmpty) return null;

    final rawPcm = allFrames[0];
    final totalSamples = rawPcm.length;

    debugPrint('WHISPER-TR: $totalSamples samples (${(totalSamples / sampleRate).toStringAsFixed(1)}s)');

    if (totalSamples < _minSamples) return null;

    final newSamples = totalSamples - _lastInferenceLength;
    if (newSamples < (sampleRate * minSecondsBetweenInference).round()) return null;

    if (_inferenceRunning) return null;
    _inferenceRunning = true;

    try {
      final start = totalSamples > _maxSamples ? totalSamples - _maxSamples : 0;
      final audioSlice = rawPcm.sublist(start);

      final audio = Float64List(audioSlice.length);
      for (int i = 0; i < audioSlice.length; i++) {
        audio[i] = audioSlice[i].toDouble();
      }

      // Debug: save raw audio for Python comparison
      final saveDir = debugAudioDir;
      if (saveDir != null) {
        try {
          _saveCounter++;
          final savePath = '$saveDir/debug_audio_$_saveCounter.pcm';
          final bytes = ByteData(audio.length * 8);
          for (int i = 0; i < audio.length; i++) {
            bytes.setFloat64(i * 8, audio[i], Endian.little);
          }
          await File(savePath).writeAsBytes(bytes.buffer.asUint8List());
          debugPrint('WHISPER-TR: saved ${audio.length} samples to $savePath');
        } catch (e) {
          debugPrint('WHISPER-TR: save failed: $e');
        }
      }

      final melFeatures = _melService.compute(audio);

      final forcedTokens = tokenizer.forcedDecoderIds(language);
      final tokenIds = await pipeline.greedyDecode(
        melFeatures: melFeatures,
        forcedTokens: forcedTokens,
      );

      _currentHypothesis = tokenizer.decode(tokenIds);
      _lastInferenceLength = totalSamples;

      debugPrint('WHISPER-TR: decoded: $_currentHypothesis (${tokenIds.length} tokens)');

      return OngoingResult(
        confirmedText: _confirmedText,
        hypothesis: _confirmedText + _currentHypothesis,
      );
    } catch (e) {
      debugPrint('WHISPER-TR ERROR: $e');
      return null;
    } finally {
      _inferenceRunning = false;
    }
  }

  @override
  void commit() {
    _confirmedText += _currentHypothesis;
    _currentHypothesis = '';
    _lastInferenceLength = 0;
  }

  @override
  void reset() {
    _confirmedText = '';
    _currentHypothesis = '';
    _lastInferenceLength = 0;
    _inferenceRunning = false;
  }

  @override
  void skipTo(int frameCount) {}
}
