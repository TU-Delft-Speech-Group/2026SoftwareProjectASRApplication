import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<RecorderService>()])
import 'view_model_test.mocks.dart';

void main() {
  group('Home page - View Model', () {
    late MockAudioRecorder recorder;
    late MockRecorderService service;
    late HomeViewModel viewModel;

    setUp(() async {
      recorder = MockAudioRecorder();
      service = MockRecorderService();
      when(recorder.hasPermission()).thenAnswer((_) async => true);
      when(service.start()).thenAnswer((_) async => {});
      viewModel = HomeViewModel(recorder: recorder, recorderService: service);
    });

    test('first toggle enables transcribing', () async {
      await withClock(Clock(() => DateTime(2026, 5, 15, 12, 00, 00)), () async {
        await viewModel.toggleTranscribing();
      });

      expect(viewModel.isTranscribing, isTrue);
      expect(viewModel.recentTranscriptions, hasLength(1));
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions.first.content, '...');
    });

    test('second toggle disables transcribing', () async {
      for (int i = 0; i < 2; i++) {
        await withClock(
          Clock(() => DateTime(2026, 5, 15, 12, 10 * i, 00)),
          () async {
            await viewModel.toggleTranscribing();
          },
        );
      }

      expect(viewModel.isTranscribing, isFalse);
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions, hasLength(1));
      expect(viewModel.recentTranscriptions.first.content, isNot('...'));
    });

    test('third toggle enables new transcribing', () async {
      for (int i = 0; i < 3; i++) {
        await withClock(
          Clock(() => DateTime(2026, 5, 15, 12, 10 * i, 00)),
          () async {
            await viewModel.toggleTranscribing();
          },
        );
      }

      expect(viewModel.isTranscribing, isTrue);
      expect(viewModel.recentTranscriptions, hasLength(2));
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions.last.label, matches('12:20'));
      expect(viewModel.recentTranscriptions.last.content, '...');
    });

    test('fourth toggle disables transcribing', () async {
      for (int i = 0; i < 4; i++) {
        await withClock(
          Clock(() => DateTime(2026, 5, 15, 12, 10 * i, 00)),
          () async {
            await viewModel.toggleTranscribing();
          },
        );
      }

      expect(viewModel.isTranscribing, isFalse);
      expect(viewModel.recentTranscriptions, hasLength(2));
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions.last.label, matches('12:20'));
      expect(viewModel.recentTranscriptions.last.content, isNot('...'));
    });
  });
}
