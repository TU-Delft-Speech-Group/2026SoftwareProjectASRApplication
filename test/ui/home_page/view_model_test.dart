import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home page - View Model', () {
    test('first toggle enables transcribing', () {
      final viewModel = HomeViewModel();

      withClock(Clock(() => DateTime(2026, 5, 15, 12, 00, 00)), () {
        viewModel.toggleTranscribing();
      });

      expect(viewModel.isTranscribing, isTrue);
      expect(viewModel.recentTranscriptions, hasLength(1));
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions.first.content, '...');
    });

    test('second toggle disables transcribing', () {
      final viewModel = HomeViewModel();

      for (int i = 0; i < 2; i++) {
        withClock(Clock(() => DateTime(2026, 5, 15, 12, 10 * i, 00)), () {
          viewModel.toggleTranscribing();
        });
      }

      expect(viewModel.isTranscribing, isFalse);
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions, hasLength(1));
      expect(viewModel.recentTranscriptions.first.content, isNot('...'));
    });

    test('third toggle enables new transcribing', () {
      final viewModel = HomeViewModel();

      for (int i = 0; i < 3; i++) {
        withClock(Clock(() => DateTime(2026, 5, 15, 12, 10 * i, 00)), () {
          viewModel.toggleTranscribing();
        });
      }

      expect(viewModel.isTranscribing, isTrue);
      expect(viewModel.recentTranscriptions, hasLength(2));
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions.last.label, matches('12:20'));
      expect(viewModel.recentTranscriptions.last.content, '...');
    });

    test('fourth toggle disables transcribing', () {
      final viewModel = HomeViewModel();

      for (int i = 0; i < 4; i++) {
        withClock(Clock(() => DateTime(2026, 5, 15, 12, 10 * i, 00)), () {
          viewModel.toggleTranscribing();
        });
      }

      expect(viewModel.isTranscribing, isFalse);
      expect(viewModel.recentTranscriptions, hasLength(2));
      expect(viewModel.recentTranscriptions.first.label, matches('12:00'));
      expect(viewModel.recentTranscriptions.last.label, matches('12:20'));
      expect(viewModel.recentTranscriptions.last.content, isNot('...'));
    });
  });
}
