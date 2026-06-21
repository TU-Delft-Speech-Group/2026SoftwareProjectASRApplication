@Tags(['accessibility'])
library;

import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/ui/add_model/widgets/add_model_page.dart';
import 'package:asr_application/ui/add_model/widgets/load_model_button.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../testing/app.dart';

@GenerateNiceMocks([MockSpec<ModelInstallController>()])
import 'accessibility_test.mocks.dart';

// This test is based on the Flutter accessibility testing documentation
// https://docs.flutter.dev/ui/accessibility/accessibility-testing
// Version 3.41.5 - 2026-05-05.
void main() {
  provideDummy<Result<void>>(Result.ok(null));

  late Widget widget;
  late MockModelInstallController mockModelInstallController;

  setUp(() {
    mockModelInstallController = MockModelInstallController();
    widget = AddModelPage(installModelController: mockModelInstallController);
  });

  Future<void> loadScreen(WidgetTester tester) async {
    await testApp(tester, widget);
  }

  group('Add Model page - Accessibility', () {
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
  });

  group('Add Model page ; Accessibility ; pick model banner', () {
    Future<void> loadScreenWithBanner(
      WidgetTester tester, {
      required Result<void> Function() onPickModel,
    }) async {
      when(
        mockModelInstallController.pickAndInstall(),
      ).thenAnswer((_) async => onPickModel());
      await testApp(tester, widget);
      await tester.tap(find.byType(LoadModelButton));
      await tester.pumpAndSettle();
    }

    testWidgets('Text contrast ; confirmation banner', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await loadScreenWithBanner(tester, onPickModel: () => Result.ok(null));

      try {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Android ; minimum tap target size 48x48 ; confirmation banner', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await loadScreenWithBanner(tester, onPickModel: () => Result.ok(null));

      try {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Text contrast ; error banner', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await loadScreenWithBanner(
        tester,
        onPickModel: () => Result.error(Exception('boom')),
      );

      try {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Android ; minimum tap target size 48x48 ; error banner', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await loadScreenWithBanner(
        tester,
        onPickModel: () => Result.error(Exception('boom')),
      );

      try {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });
  });
}
