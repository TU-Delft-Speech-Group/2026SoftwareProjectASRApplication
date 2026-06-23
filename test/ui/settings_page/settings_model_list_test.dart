import 'dart:collection';

import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/domain/models/model/model_list.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/ui/settings/widgets/settings_model_list.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<ModelInstallController>()])
import 'settings_model_list_test.mocks.dart';

void main() {
  late MockModelInstallController controller;

  setUp(() {
    controller = MockModelInstallController();
    provideDummy<Result<ModelList>>(
      Result.ok(ModelList(modelNames: UnmodifiableListView(<String>[]))),
    );
    provideDummy<Result<void>>(Result.ok(null));
    when(controller.activeModelName).thenReturn('model-a');
    when(controller.getModelList()).thenAnswer(
      (_) =>
          ModelList(modelNames: UnmodifiableListView(['model-a', 'model-b'])),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    Future<Result<void>> Function(String modelName)? onModelSelected,
    Future<void> Function()? onModelDeleted,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SettingsModelList(
            modelController: controller,
            onModelSelected: onModelSelected,
            onModelDeleted: onModelDeleted,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows no confirmation or error snackbar initially', (
    tester,
  ) async {
    await pump(tester, onModelSelected: (_) async => Result.ok(null));

    expect(find.text(AppLocalizationsEn().settings__modelLoaded), findsNothing);
  });

  testWidgets('shows a confirmation snackbar after a successful model load', (
    tester,
  ) async {
    await pump(tester, onModelSelected: (_) async => Result.ok(null));

    await tester.tap(find.text('model-b'));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().settings__modelLoaded),
      findsOneWidget,
    );
  });

  testWidgets('shows an error snackbar instead when loading fails', (
    tester,
  ) async {
    final error = Exception('boom');
    await pump(tester, onModelSelected: (_) async => Result.error(error));

    await tester.tap(find.text('model-b'));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().settings__modelLoaded), findsNothing);
    expect(find.text(error.toString()), findsOneWidget);
  });

  testWidgets('replaces the previous snackbar when a new selection starts', (
    tester,
  ) async {
    var shouldFail = false;
    await pump(
      tester,
      onModelSelected: (_) async {
        if (shouldFail) return Result.error(Exception('boom'));
        return Result.ok(null);
      },
    );

    await tester.tap(find.text('model-b'));
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizationsEn().settings__modelLoaded),
      findsOneWidget,
    );

    when(controller.activeModelName).thenReturn('model-b');
    shouldFail = true;
    await tester.tap(find.text('model-a'));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().settings__modelLoaded), findsNothing);
  });

  testWidgets('shows a delete button for every model', (tester) async {
    await pump(tester);

    expect(
      find.byKey(const ValueKey('settings-model-delete-model-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-model-delete-model-b')),
      findsOneWidget,
    );
  });

  testWidgets('delete button has a tooltip but no visible text label, '
      'matching the icon-only style used elsewhere (e.g. SettingsButton)', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.byTooltip(AppLocalizationsEn().settings__deleteModel),
      findsNWidgets(2),
    );
    // No dialog is open yet, so any match here would have to come from the
    // card itself rather than the confirmation dialog's own button.
    expect(find.text(AppLocalizationsEn().settings__deleteModel), findsNothing);
  });

  testWidgets('tapping delete shows a confirmation dialog and does not delete '
      'until confirmed', (tester) async {
    await pump(tester);

    await tester.tap(
      find.byKey(const ValueKey('settings-model-delete-model-b')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().settings__deleteModelConfirmTitle),
      findsOneWidget,
    );
    verifyNever(controller.deleteModel(any));

    await tester.tap(find.text(AppLocalizationsEn().settings__cancel));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().settings__deleteModelConfirmTitle),
      findsNothing,
    );
    verifyNever(controller.deleteModel(any));
  });

  testWidgets('confirming the dialog deletes the model', (tester) async {
    when(
      controller.deleteModel('model-b'),
    ).thenAnswer((_) async => Result.ok(null));
    await pump(tester);

    await tester.tap(
      find.byKey(const ValueKey('settings-model-delete-model-b')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().settings__deleteModel));
    await tester.pumpAndSettle();

    verify(controller.deleteModel('model-b')).called(1);
  });

  testWidgets('shows a confirmation snackbar after a successful deletion', (
    tester,
  ) async {
    when(
      controller.deleteModel('model-b'),
    ).thenAnswer((_) async => Result.ok(null));
    await pump(tester);

    expect(
      find.text(AppLocalizationsEn().settings__deleteModelSuccess),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-model-delete-model-b')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().settings__deleteModel));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().settings__deleteModelSuccess),
      findsOneWidget,
    );
  });

  testWidgets('clears the previous confirmation when a new delete attempt '
      'fails', (tester) async {
    when(
      controller.deleteModel('model-b'),
    ).thenAnswer((_) async => Result.ok(null));
    await pump(tester);

    await tester.tap(
      find.byKey(const ValueKey('settings-model-delete-model-b')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().settings__deleteModel));
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizationsEn().settings__deleteModelSuccess),
      findsOneWidget,
    );

    when(controller.activeModelName).thenReturn('model-a');
    when(
      controller.deleteModel('model-a'),
    ).thenAnswer((_) async => Result.error(Exception('boom')));
    await tester.tap(
      find.byKey(const ValueKey('settings-model-delete-model-a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().settings__deleteModel));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().settings__deleteModelSuccess),
      findsNothing,
    );
    expect(
      find.text(AppLocalizationsEn().errors__deleteModelFailed),
      findsOneWidget,
    );
  });

  testWidgets('calls onModelDeleted when the deleted model was active', (
    tester,
  ) async {
    when(
      controller.deleteModel('model-a'),
    ).thenAnswer((_) async => Result.ok(null));
    var called = false;
    await pump(tester, onModelDeleted: () async => called = true);

    await tester.tap(
      find.byKey(const ValueKey('settings-model-delete-model-a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().settings__deleteModel));
    await tester.pumpAndSettle();

    expect(called, isTrue);
  });

  testWidgets('does not call onModelDeleted when the deleted model was not '
      'active', (tester) async {
    when(
      controller.deleteModel('model-b'),
    ).thenAnswer((_) async => Result.ok(null));
    var called = false;
    await pump(tester, onModelDeleted: () async => called = true);

    await tester.tap(
      find.byKey(const ValueKey('settings-model-delete-model-b')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().settings__deleteModel));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('shows an error snackbar when deletion fails', (tester) async {
    when(
      controller.deleteModel('model-b'),
    ).thenAnswer((_) async => Result.error(Exception('boom')));
    await pump(tester);

    await tester.tap(
      find.byKey(const ValueKey('settings-model-delete-model-b')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().settings__deleteModel));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().errors__deleteModelFailed),
      findsOneWidget,
    );
  });

  testWidgets('truncates a long model name instead of wrapping or '
      'overflowing on a narrow screen', (tester) async {
    // logical size matching a 1080x2340 physical Android screen at ~2.625x.
    await tester.binding.setSurfaceSize(const Size(411, 891));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const longName = 'EnglishGigaspeechConformerFBank_M01';
    when(controller.getModelList()).thenAnswer(
      (_) => ModelList(modelNames: UnmodifiableListView([longName])),
    );

    await pump(tester);

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.text(longName));
    // a single line at the default body font size is well under 30px tall;
    // wrapping to a second line (the pre-fix behavior) would roughly double
    // it.
    expect(size.height, lessThan(30));
  });
}
