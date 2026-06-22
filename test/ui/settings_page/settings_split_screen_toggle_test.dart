import 'package:asr_application/ui/settings/widgets/settings_split_screen_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/app.dart';

void main() {
  Future<void> loadScreen(WidgetTester tester) async {
    await testApp(
      tester,
      const Scaffold(body: SettingsSplitScreenToggle()),
    );
  }

  group('Split screen toggle indicator', () {
    testWidgets('shows an unchecked icon when split screen is off', (
      tester,
    ) async {
      await loadScreen(tester);

      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('switches to a checked icon when toggled on, independently '
        'of the border color', (tester) async {
      await loadScreen(tester);

      await tester.tap(find.byKey(const ValueKey('settings-split-screen-toggle')));
      await tester.pumpAndSettle();

      // the glyph itself changes, not just the color, so the state is
      // perceivable without relying on color alone.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    });

    testWidgets('reports the toggle state through semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await loadScreen(tester);
      final toggle = find.byKey(
        const ValueKey('settings-split-screen-toggle'),
      );

      expect(
        tester.getSemantics(toggle),
        matchesSemantics(
          isButton: true,
          isToggled: false,
          hasToggledState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(toggle),
        matchesSemantics(
          isButton: true,
          isToggled: true,
          hasToggledState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      handle.dispose();
    });
  });
}
