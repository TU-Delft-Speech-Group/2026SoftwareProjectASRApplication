@Tags(['accessibility'])
library;

import 'package:asr_application/services/audio/recorder_service.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:record/record.dart';

import '../../../testing/app.dart';
@GenerateNiceMocks([MockSpec<AudioRecorder>()])
@GenerateNiceMocks([MockSpec<RecorderService>()])
import 'accessibility_test.mocks.dart';

// This test is based on the Flutter accessibility testing documentation
// https://docs.flutter.dev/ui/accessibility/accessibility-testing
// Version 3.41.5 - 2026-05-05.
void main() {
  late MockAudioRecorder recorder;
  late MockRecorderService service;
  late HomeViewModel viewModel;

  setUp(() {
    recorder = MockAudioRecorder();
    service = MockRecorderService();
    when(recorder.hasPermission()).thenAnswer((_) async => true);
    when(service.start()).thenAnswer((_) async => {});
    viewModel = HomeViewModel(recorder: recorder, recorderService: service);
  });

  Future<void> loadScreen(WidgetTester tester) async {
    await testApp(tester, HomePage(viewModel: viewModel));
  }

  group('Home page - Accessibility', () {
    testWidgets('Android - minimum tap target size 48x48', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await loadScreen(tester);

      // Checks that tappable nodes have a minimum size of 48 by 48 pixels
      // for Android.
      try {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('iOS - minimum tap target size 44x44', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await loadScreen(tester);

      // Checks that tappable nodes have a minimum size of 44 by 44 pixels
      // for iOS.
      try {
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Tappable nodes are labeled', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await loadScreen(tester);

      // Checks that touch targets with a tap or long press action are labeled.
      try {
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Text contrast - initial page', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await loadScreen(tester);

      // Checks whether semantic nodes meet the minimum text contrast levels.
      // The recommended text contrast is 3:1 for larger text
      // (18 point and above regular).
      try {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Text contrast - transcribing', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await loadScreen(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
