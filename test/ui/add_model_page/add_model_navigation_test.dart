import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/ui/add_model/widgets/add_model_text_field.dart';
import 'package:asr_application/ui/add_model/widgets/add_model_page.dart';
import 'package:asr_application/ui/add_model/widgets/download_model_button.dart';
import 'package:asr_application/ui/add_model/widgets/load_model_button.dart';
import 'package:asr_application/ui/add_model/widgets/model_source_separator.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/core/widgets/app_banner.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:asr_application/ui/home/widgets/settings_button.dart';
import 'package:asr_application/ui/settings/widgets/add_model_button.dart';
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

abstract class MockDownloadFunctionbase {
  Future<Result<void>> call(String modelUri);
}

class MockDownloadFunction extends Mock implements MockDownloadFunctionbase {
  @override
  Future<Result<void>> call(String modelUri) =>
      super.noSuchMethod(
            Invocation.method(#call, []),
            returnValue: Future<Result<void>>.value(Result.ok(null)),
          )
          as Future<Result<void>>;
}

void main() {
  late SettingsRepository settingsRepository;

  Future<void> generateWidget(
    WidgetTester tester, {
    Future<Result<void>> Function()? onPickModel,
    Future<Result<void>> Function(String modelUri)? onDownloadModel,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));

    settingsRepository = SettingsRepository(
      save: (String k, String v) async => Mock(),
      preferences: {},
    );

    await tester.pumpWidget(
      AppSettingsScope(
        settings: settingsRepository,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(fontFamily: ThemeFontFamily().arial),
          home: HomePage(
            viewModel: HomeViewModel(),
            onPickModel: onPickModel,
            onDownloadModel: onDownloadModel,
          ),
        ),
      ),
    );
  }

  Future<void> openAddModelPage(
    WidgetTester tester, {
    Future<Result<void>> Function()? onPickModel,
    Future<Result<void>> Function(String modelUri)? onDownloadModel,
  }) async {
    await generateWidget(
      tester,
      onPickModel: onPickModel,
      onDownloadModel: onDownloadModel,
    );

    await tester.tap(find.byType(SettingsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AddModelButton));
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
      await openAddModelPage(
        tester,
        onPickModel: mock.call,
        onDownloadModel: (String modelUri) => mock.call(),
      );

      expect(find.byType(AddModelTextField), findsNWidgets(2));
      expect(find.text(AppLocalizationsEn().addModel__name), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().addModel__modelLink),
        findsOneWidget,
      );
      expect(find.text('English v1'), findsOneWidget);
      expect(
        find.text(
          'https://huggingface.co/user/repo/resolve/main/model.asrmodel',
        ),
        findsOneWidget,
      );
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

    group('pick model', () {
      testWidgets('button appears when a handler is provided', (tester) async {
        final mock = MockPickFunction();
        when(mock.call()).thenAnswer((_) async => Result.ok(null));
        await openAddModelPage(tester, onPickModel: mock.call);

        expect(find.byType(LoadModelButton), findsOneWidget);
        expect(
          find.text(AppLocalizationsEn().addModel__loadModel),
          findsOneWidget,
        );
      });

      testWidgets('button runs provided handler', (tester) async {
        final mock = MockPickFunction();
        when(mock.call()).thenAnswer((_) async => Result.ok(null));
        await openAddModelPage(tester, onPickModel: mock.call);

        await tester.tap(find.text(AppLocalizationsEn().addModel__loadModel));
        await tester.pumpAndSettle();

        verify(mock.call()).called(1);
      });

      testWidgets('button is hidden without a handler', (tester) async {
        await openAddModelPage(tester);

        expect(find.byType(LoadModelButton), findsNothing);
      });

      testWidgets('warning is shown when handler returns an error', (
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
    });

    group('download model', () {
      testWidgets('button appears when a handler is provided', (tester) async {
        final mock = MockDownloadFunction();
        when(mock.call('')).thenAnswer((_) async => Result.ok(null));
        await openAddModelPage(tester, onDownloadModel: mock.call);

        expect(find.byType(DownloadModelButton), findsOneWidget);
        expect(
          find.text(AppLocalizationsEn().addModel__downloadModel),
          findsOneWidget,
        );
      });

      testWidgets('button runs provided handler with text input', (
        tester,
      ) async {
        final modelUri = 'modelUri';
        final mock = MockDownloadFunction();
        when(mock.call(modelUri)).thenAnswer((_) async => Result.ok(null));
        await openAddModelPage(tester, onDownloadModel: mock.call);

        await tester.enterText(find.byType(TextField).first, modelUri);
        await tester.tap(
          find.text(AppLocalizationsEn().addModel__downloadModel),
        );
        await tester.pumpAndSettle();

        verify(mock.call(modelUri)).called(1);
      });

      testWidgets('button is hidden without a handler', (tester) async {
        await openAddModelPage(tester);

        expect(find.byType(LoadModelButton), findsNothing);
      });

      testWidgets('warning is shown when handler returns an error', (
        tester,
      ) async {
        final mock = MockDownloadFunction();
        when(mock.call('')).thenAnswer((_) async => Result.error(Exception()));
        await openAddModelPage(tester, onDownloadModel: mock.call);

        await tester.tap(find.byType(DownloadModelButton));
        await tester.pumpAndSettle();

        expect(find.byType(WarningBanner), findsOneWidget);
        expect(
          find.text(AppLocalizationsEn().errors__filePickerWarning),
          findsOneWidget,
        );
      });
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
