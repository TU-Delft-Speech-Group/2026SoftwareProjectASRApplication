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
    provideDummy(
      Result.ok(ModelList(modelNames: UnmodifiableListView(<String>[]))),
    );
    when(controller.activeModelName).thenReturn('model-a');
    when(controller.getModelList()).thenAnswer(
      (_) async => Result.ok(
        ModelList(modelNames: UnmodifiableListView(['model-a', 'model-b'])),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    Future<Result<void>> Function(String modelName)? onModelSelected,
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows no confirmation or error banner initially', (
    tester,
  ) async {
    await pump(tester, onModelSelected: (_) async => Result.ok(null));

    expect(find.text(AppLocalizationsEn().settings__modelLoaded), findsNothing);
  });

  testWidgets('shows a confirmation banner after a successful model load', (
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

  testWidgets('shows an error banner instead when loading fails', (
    tester,
  ) async {
    final error = Exception('boom');
    await pump(tester, onModelSelected: (_) async => Result.error(error));

    await tester.tap(find.text('model-b'));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().settings__modelLoaded), findsNothing);
    expect(find.text(error.toString()), findsOneWidget);
  });

  testWidgets('clears the previous banner when a new selection starts', (
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
}
