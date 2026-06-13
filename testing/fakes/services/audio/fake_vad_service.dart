import 'package:asr_application/services/audio/vad_service.dart';

class FakeVadService implements VadService {
  final _responses = <bool>[];
  var initializeCalls = 0;
  var resetCalls = 0;
  var disposeCalls = 0;
  final List<List<double>> samplesReceived = [];

  void queueResponse(bool isSpeech) => _responses.add(isSpeech);

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<bool> isSpeech(List<double> samples) async {
    samplesReceived.add(List.of(samples));
    if (_responses.isEmpty) {
      throw StateError('FakeVadService has no queued response for isSpeech().');
    }
    return _responses.removeAt(0);
  }

  @override
  Future<void> reset() async => resetCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}
