import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/ui/add_model/widgets/add_model_text_field.dart';
import 'package:asr_application/ui/add_model/widgets/add_model_page.dart';
import 'package:asr_application/ui/add_model/widgets/download_model_button.dart';
import 'package:asr_application/ui/add_model/widgets/load_model_button.dart';
import 'package:asr_application/ui/add_model/widgets/model_source_separator.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/core/widgets/app_banner.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

abstract class MockPickFunctionBase {
  Future<Result<void>> call();
}

class MockPickFunction extends Mock implements MockPickFunctionBase {
  @override
  Future<Result<void>> call() =>
      super.noSuchMethod(
            Invocation.method(#call, []),
            returnValue: Future<Result<void>>.value(Result.ok(null)),
          )
          as Future<Result<void>>;
}

void main() {
  Future<void> generateWidget(
    WidgetTester tester, {
    Future<Result<void>> Function()? onPickModel,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(fontFamily: ThemeFontFamily().arial),
        home: HomePage(viewModel: HomeViewModel(), onPickModel: onPickModel),
      ),
    );
  }

  Future<void> openAddModelPage(
    WidgetTester tester, {
    Future<Result<void>> Function()? onPickModel,
  }) async {
    await generateWidget(tester, onPickModel: onPickModel);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().settings__addModel));
    await tester.pumpAndSettle();
  }

  group('Add model navigation', () {
    testWidgets('add model button opens add model page', (tester) async {
      await openAddModelPage(tester);

      expect(find.byType(AddModelPage), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().settings__addModel),
        findsOneWidget,
      );
      expect(find.text(AppLocalizationsEn().settings__back), findsOneWidget);
      expect(find.text(AppLocalizationsEn().settings__title), findsNothing);
    });

    testWidgets('add model page shows localized form fields', (tester) async {
      final mock = MockPickFunction();
      when(mock.call()).thenAnswer((_) async => Result.ok(null));
      await openAddModelPage(tester, onPickModel: mock.call);

      expect(find.byType(AddModelTextField), findsNWidgets(2));
      expect(find.text(AppLocalizationsEn().addModel__name), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().addModel__modelLink),
        findsOneWidget,
      );
      expect(find.text('English v1'), findsOneWidget);
      expect(find.text('https://huggingface.co/user/model'), findsOneWidget);
      expect(find.byType(DownloadModelButton), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().addModel__downloadModel),
        findsOneWidget,
      );
      expect(find.byType(ModelSourceSeparator), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().addModel__sourceSeparator),
        findsOneWidget,
      );
    });

    testWidgets('back button returns from add model page to settings page', (
      tester,
    ) async {
      await openAddModelPage(tester);

      await tester.tap(find.text(AppLocalizationsEn().settings__back));
      await tester.pumpAndSettle();

      expect(find.byType(AddModelPage), findsNothing);
      expect(find.text(AppLocalizationsEn().settings__title), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().settings__addModel),
        findsOneWidget,
      );
    });

    testWidgets('load model button appears when a picker is provided', (
      tester,
    ) async {
      final mock = MockPickFunction();
      when(mock.call()).thenAnswer((_) async => Result.ok(null));
      await openAddModelPage(tester, onPickModel: mock.call);

      expect(find.byType(LoadModelButton), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().addModel__loadModel),
        findsOneWidget,
      );
    });

    testWidgets('load model button runs provided picker', (tester) async {
      final mock = MockPickFunction();
      when(mock.call()).thenAnswer((_) async => Result.ok(null));
      await openAddModelPage(tester, onPickModel: mock.call);

      await tester.tap(find.text(AppLocalizationsEn().addModel__loadModel));
      await tester.pumpAndSettle();

      verify(mock.call()).called(1);
    });

    testWidgets('load model button is hidden without a picker', (tester) async {
      await openAddModelPage(tester);

      expect(find.byType(LoadModelButton), findsNothing);
    });

    testWidgets('warning is shown when picker returns an error', (
      tester,
    ) async {
      final mock = MockPickFunction();
      when(mock.call()).thenAnswer((_) async => Result.error(Exception()));
      await openAddModelPage(tester, onPickModel: mock.call);

      await tester.tap(find.byType(LoadModelButton));
      await tester.pumpAndSettle();

      expect(find.byType(WarningBanner), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().errors__filePickerWarning),
        findsOneWidget,
      );
    });

    testWidgets('warning disappears when picker returns succesfully', (
      tester,
    ) async {
      final mock = MockPickFunction();
      when(mock.call()).thenAnswer((_) async => Result.error(Exception()));
      await openAddModelPage(tester, onPickModel: mock.call);

      await tester.tap(find.byType(LoadModelButton));
      await tester.pumpAndSettle();

      expect(find.byType(WarningBanner), findsOneWidget);

      when(mock.call()).thenAnswer((_) async => Result.ok(null));
      await tester.tap(find.byType(LoadModelButton));
      await tester.pumpAndSettle();

      expect(find.byType(WarningBanner), findsNothing);
    });
  });
}
