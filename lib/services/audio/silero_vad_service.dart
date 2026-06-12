import 'package:flutter/foundation.dart';

import '../shared/onnx/onnx.dart';
import 'vad_service.dart';

const _defaultAssetPath = 'assets/silero_vad.onnx';

const _chunkSize = 512; // 32 ms at 16 kHz
const _contextSize = 64; // prepended to each chunk, per Python wrapper
const _sampleRate = 16000;
const _stateSize = 128; // combined LSTM hidden+cell state per direction
const _defaultThreshold = 0.05;

// Silero VAD ONNX input/output names (current model from src/silero_vad/data/)
const _inputName = 'input';
const _srName = 'sr';
const _stateName = 'state';
const _outputName = 'output';
const _stateNName = 'stateN';

/* voice activity detector backed by Silero VAD ONNX model;
  internally buffers samples so the caller can pass arbitrary chunk sizes;
  the model receives _chunkSize samples at a time;
  recurrent state persists across isSpeech calls within a session and
  is reset by reset
*/
class SileroVadService implements VadService {
  SileroVadService({
    String assetPath = _defaultAssetPath,
    double threshold = _defaultThreshold,
    double? exitThreshold,
    OnnxInferenceBackendContract? backend,
  }) : _assetPath = assetPath,
       _threshold = threshold,
       _exitThreshold = exitThreshold ?? threshold,
       _backend = backend ?? OnnxInferenceBackend();

  final String _assetPath;
  final double _threshold;
  // Hysteresis: once in speech mode, stay until probability drops below this.
  // Equals _threshold when hysteresis is disabled.
  final double _exitThreshold;
  final OnnxInferenceBackendContract _backend;

  OnnxInferenceSessionContract? _session;

  // Recurrent state. shape [2, 1, 128] flattened.
  Float32List _state = Float32List(2 * _stateSize);

  // Last _contextSize samples from the previous chunk, prepended to each new
  // chunk before inference.
  Float32List _context = Float32List(_contextSize);

  // samples waiting to fill the next 512-sample window
  final List<double> _buffer = [];

  bool _inSpeech = false;

  bool get isInitialized => _session != null;

  @override
  Future<void> initialize() async {
    if (_session != null) return;
    _session = await _backend.createSessionFromAsset(_assetPath);
  }

  @override
  Future<bool> isSpeech(List<double> samples) async {
    final session = _session;
    if (session == null) {
      throw StateError('SileroVadService must be initialized before use.');
    }

    _buffer.addAll(samples);

    var speechDetected = false;
    while (_buffer.length >= _chunkSize) {
      final chunk = Float32List.fromList(_buffer.sublist(0, _chunkSize));
      _buffer.removeRange(0, _chunkSize);

      final probability = await _runChunk(session, chunk);
      if (_inSpeech) {
        if (probability >= _exitThreshold) {
          speechDetected = true;
        } else {
          _inSpeech = false;
        }
      } else if (probability >= _threshold) {
        _inSpeech = true;
        speechDetected = true;
      }
    }

    return speechDetected;
  }

  @override
  Future<void> reset() async {
    _state = Float32List(2 * _stateSize);
    _context = Float32List(_contextSize);
    _buffer.clear();
    _inSpeech = false;
  }

  @override
  Future<void> dispose() async {
    final session = _session;
    _session = null;
    await session?.close();
  }

  Future<double> _runChunk(
    OnnxInferenceSessionContract session,
    Float32List chunk,
  ) async {
    final inputData = Float32List(_contextSize + _chunkSize)
      ..setRange(0, _contextSize, _context)
      ..setRange(_contextSize, _contextSize + _chunkSize, chunk);
    final inputTensor = await _backend.createTensor(
      inputData,
      [1, _contextSize + _chunkSize],
    );
    _context = Float32List.fromList(
      chunk.sublist(_chunkSize - _contextSize),
    );
    final srTensor = await _backend.createTensor(
      Int64List.fromList([_sampleRate]),
      [1],
    );
    final stateTensor = await _backend.createTensor(_state, [2, 1, _stateSize]);

    Map<String, OnnxTensorContract> outputs;
    try {
      outputs = await session.run({
        _inputName: inputTensor,
        _srName: srTensor,
        _stateName: stateTensor,
      });
    } finally {
      await _safeDisposeAll([inputTensor, srTensor, stateTensor]);
    }

    try {
      final outputTensor = outputs[_outputName];
      final stateNTensor = outputs[_stateNName];

      if (outputTensor == null || stateNTensor == null) {
        throw StateError(
          'Silero VAD session did not return expected output tensors '
          '($_outputName, $_stateNName).',
        );
      }

      final probability = (await outputTensor.asFloat32List()).first;
      _state = await stateNTensor.asFloat32List();

      return probability;
    } finally {
      await _safeDisposeAll(outputs.values);
    }
  }

  Future<void> _safeDisposeAll(Iterable<OnnxTensorContract> tensors) async {
    for (final tensor in tensors) {
      try {
        await tensor.dispose();
      } catch (error) {
        debugPrint('SileroVadService: error disposing tensor: $error');
      }
    }
  }
}
