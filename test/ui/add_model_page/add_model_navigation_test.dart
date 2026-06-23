import 'package:asr_application/data/repositories/settings_repository.dart';
import 'package:asr_application/exceptions/model/invalid_model_file_exception.dart';
import 'package:asr_application/l10n/generated/app_localizations.dart';
import 'package:asr_application/l10n/generated/app_localizations_en.dart';
import 'package:asr_application/services/model_install/model_install_controller.dart';
import 'package:asr_application/ui/add_model/widgets/add_model_text_field.dart';
import 'package:asr_application/ui/add_model/widgets/add_model_page.dart';
import 'package:asr_application/ui/add_model/widgets/download_model_button.dart';
import 'package:asr_application/ui/add_model/widgets/load_model_button.dart';
import 'package:asr_application/ui/add_model/widgets/model_source_separator.dart';
import 'package:asr_application/ui/core/app_settings_scope.dart';
import 'package:asr_application/ui/core/theme_font.dart';
import 'package:asr_application/ui/home/view_models/home_viewmodel.dart';
import 'package:asr_application/ui/home/widgets/home_page.dart';
import 'package:asr_application/ui/settings/widgets/add_model_button.dart';
import 'package:asr_application/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<ModelInstallController>()])
import 'add_model_navigation_test.mocks.dart';

void main() {
  provideDummy<Result<void>>(Result.ok(null));
  provideDummy<Result<bool>>(Result.ok(false));

  late SettingsRepository settingsRepository;
  late MockModelInstallController mockModelInstallController;

  setUp(() {
    mockModelInstallController = MockModelInstallController();
  });

  tearDown(() {
    mockModelInstallController.dispose();
  });

  Future<void> generateWidget(WidgetTester tester) async {
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
            modelController: mockModelInstallController,
          ),
        ),
      ),
    );
  }

  Future<void> openAddModelPage(WidgetTester tester) async {
    await generateWidget(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
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
      await openAddModelPage(tester);

      expect(find.byType(AddModelTextField), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().addModel__modelLink),
        findsOneWidget,
      );
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
      setUp(() {
        when(
          mockModelInstallController.pickAndInstall(),
        ).thenAnswer((_) async => Result.ok(true));
      });

      testWidgets('button runs ModelInstallController::pickAndInstall', (
        tester,
      ) async {
        await openAddModelPage(tester);

        await tester.tap(find.byType(LoadModelButton));
        await tester.pumpAndSettle();

        verify(mockModelInstallController.pickAndInstall()).called(1);
      });

      testWidgets('warning snackbar is shown when picker returns an error', (
        tester,
      ) async {
        await openAddModelPage(tester);

        when(
          mockModelInstallController.pickAndInstall(),
        ).thenAnswer((_) async => Result.error(Exception()));
        await tester.tap(find.byType(LoadModelButton));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().errors__addModelError),
          findsOneWidget,
        );
      });

      testWidgets('wrong file type shows a specific snackbar message', (
        tester,
      ) async {
        await openAddModelPage(tester);

        when(mockModelInstallController.pickAndInstall()).thenAnswer(
          (_) async =>
              Result.error(const InvalidModelFileException('photo.jpg')),
        );
        await tester.tap(find.byType(LoadModelButton));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().errors__wrongFileType),
          findsOneWidget,
        );
        expect(
          find.text(AppLocalizationsEn().errors__addModelError),
          findsNothing,
        );
      });

      testWidgets('warning snackbar is replaced when picker returns '
          'succesfully', (tester) async {
        await openAddModelPage(tester);

        when(
          mockModelInstallController.pickAndInstall(),
        ).thenAnswer((_) async => Result.error(Exception()));
        await tester.tap(find.byType(LoadModelButton));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().errors__addModelError),
          findsOneWidget,
        );

        when(
          mockModelInstallController.pickAndInstall(),
        ).thenAnswer((_) async => Result.ok(true));
        await tester.tap(find.byType(LoadModelButton));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().errors__addModelError),
          findsNothing,
        );
      });

      testWidgets('confirmation snackbar is shown when handler succeeds', (
        tester,
      ) async {
        await openAddModelPage(tester);

        expect(
          find.text(AppLocalizationsEn().addModel__modelAdded),
          findsNothing,
        );

        await tester.tap(find.byType(LoadModelButton));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().addModel__modelAdded),
          findsOneWidget,
        );
      });

      testWidgets('no snackbar is shown when the picker is cancelled '
          'without choosing a file', (tester) async {
        await openAddModelPage(tester);

        when(
          mockModelInstallController.pickAndInstall(),
        ).thenAnswer((_) async => Result.ok(false));
        await tester.tap(find.byType(LoadModelButton));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().addModel__modelAdded),
          findsNothing,
        );
        expect(
          find.text(AppLocalizationsEn().errors__addModelError),
          findsNothing,
        );
        // The button is enabled again, proving the loading banner didn't
        // get stuck after a cancelled pick.
        expect(
          tester
              .widget<FilledButton>(
                find.descendant(
                  of: find.byType(LoadModelButton),
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNotNull,
        );
      });
    });

    group('download model', () {
      setUp(() {
        when(
          mockModelInstallController.downloadAndInstall(any),
        ).thenAnswer((_) async => Result.ok(null));
      });

      testWidgets('button calls ModelInstalController::downloadAndInstall', (
        tester,
      ) async {
        final modelUri = 'modelUri';
        await openAddModelPage(tester);

        await tester.enterText(find.byType(TextField).first, modelUri);
        await tester.tap(
          find.text(AppLocalizationsEn().addModel__downloadModel),
        );
        await tester.pumpAndSettle();

        verify(mockModelInstallController.downloadAndInstall(any)).called(1);
      });

      testWidgets('warning snackbar is shown when download returns an error', (
        tester,
      ) async {
        await openAddModelPage(tester);
        when(
          mockModelInstallController.downloadAndInstall(any),
        ).thenAnswer((_) async => Result.error(Exception()));

        await tester.tap(find.byType(DownloadModelButton));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().errors__addModelError),
          findsOneWidget,
        );
      });

      testWidgets('confirmation snackbar is shown when handler succeeds', (
        tester,
      ) async {
        await openAddModelPage(tester);

        expect(
          find.text(AppLocalizationsEn().addModel__modelAdded),
          findsNothing,
        );

        await tester.tap(find.byType(DownloadModelButton));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().addModel__modelAdded),
          findsOneWidget,
        );
      });
    });

    testWidgets('warning snackbar is replaced when download returns '
        'succesfully', (tester) async {
      await openAddModelPage(tester);

      when(
        mockModelInstallController.downloadAndInstall(any),
      ).thenAnswer((_) async => Result.error(Exception()));
      await tester.tap(find.byType(DownloadModelButton));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().errors__addModelError),
        findsOneWidget,
      );

      when(
        mockModelInstallController.downloadAndInstall(any),
      ).thenAnswer((_) async => Result.ok(null));
      await tester.tap(find.byType(DownloadModelButton));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().errors__addModelError),
        findsNothing,
      );
    });

    testWidgets('confirmation snackbar is replaced when a later attempt '
        'fails', (tester) async {
      await openAddModelPage(tester);

      when(
        mockModelInstallController.pickAndInstall(),
      ).thenAnswer((_) async => Result.ok(true));
      await tester.tap(find.byType(LoadModelButton));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().addModel__modelAdded),
        findsOneWidget,
      );

      when(
        mockModelInstallController.pickAndInstall(),
      ).thenAnswer((_) async => Result.error(Exception()));
      await tester.tap(find.byType(LoadModelButton));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().addModel__modelAdded),
        findsNothing,
      );
      expect(
        find.text(AppLocalizationsEn().errors__addModelError),
        findsOneWidget,
      );
    });
  });
}
